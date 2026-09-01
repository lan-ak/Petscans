#!/usr/bin/env bash
#
# Detached, sleep-resistant runner for the retailer sweep.
#
# Three separate problems, three separate answers:
#
#   terminal/VS Code closed  -> nohup + background, so the job ignores SIGHUP and is reparented
#                               to launchd when this script exits. (macOS has no setsid.)
#   machine idles to sleep   -> a `caffeinate -dimsw <pid>` alongside the job holds display,
#                               idle, and system sleep, and releases the moment that pid
#                               exits. The `-w` form is deliberate: caffeinate-as-parent
#                               leaves the assertion's lifetime tied to a process tree that is
#                               awkward to reason about, and an assertion that outlives the
#                               sweep would stop the Mac ever sleeping again. This works on AC
#                               power. Closing the lid still sleeps a MacBook regardless
#                               (clamshell sleep is not something a process can veto), hence:
#   machine slept anyway     -> every collector resumes from its .done ledger. Sleep looks like
#                               a network partition; in-flight fetches retry with backoff, and
#                               anything lost is re-fetched on the next run. Re-running is
#                               always safe and never duplicates work.
#
# BEFORE YOU RUN THIS: docs/catalog-expansion.md
#
#   A catalog expansion can silently remove allergen protection from pets without failing a
#   build or changing a score. Allergen checking only runs on ingredients the matcher
#   resolves, so a new label spelling that resolves to nothing is invisible to it — the app
#   then reports "No known allergens detected" over a food whose label says fish. Take a
#   matchkit baseline first, and walk steps 4-7 of that doc afterwards.
#
# Usage:
#   ./harvest.sh all            rens -> petsmart -> petvalu -> ingest -> pack -> group  (detached)
#   ./harvest.sh expand         pets at home (UK) -> petbarn (AU) -> petco (US) -> ingest -> pack -> group
#   ./harvest.sh intl           the two international legs only
#   ./harvest.sh rens           one stage, detached
#   ./harvest.sh petsmart
#   ./harvest.sh petvalu
#   ./harvest.sh uk             one international leg, detached
#   ./harvest.sh au
#   ./harvest.sh ingest         merge harvested JSONL into catalog.sqlite (foreground)
#   ./harvest.sh status         progress of the running job
#   ./harvest.sh logs           follow the live log
#   ./harvest.sh stop           stop cleanly; ledgers stay valid, re-run to resume
#
set -euo pipefail

cd "$(dirname "$0")"
WORK="$PWD/harvest"
LOG="$WORK/harvest.log"
PIDFILE="$WORK/harvest.pid"
PETVALU_BUDGET="${PETVALU_BUDGET:-1200}"
# Pets at Home ~1,771 products, Petbarn ~1,663; one credit each. 4000 covers both with room.
INTL_BUDGET="${INTL_BUDGET:-4000}"

# Ingest reads every *.jsonl in the work dir when it is not told which. That dir now also holds
# harvests that are not catalog rows at all — the image and guaranteed-analysis backfills carry
# an empty `ingredients` on purpose and are applied by their own commands. They are rejected
# rather than inserted, so the glob is harmless today, but naming the retailer harvests keeps it
# that way once a non-catalog harvest does have ingredients.
RETAILER_HARVESTS="rens,petsmart-ca,petsmart-us,petvalu,petvalu-performatrin,petsathome,petbarn,petco"
# Petco lists ~5,400 dog/cat consumable pages, ~2 barcodes each (size variants).
PETCO_BUDGET="${PETCO_BUDGET:-6000}"

mkdir -p "$WORK"

run() { npm run --silent petcatalog -- "$@"; }

running() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# Signal a whole process tree, deepest first, so the node harness gets the TERM (and drains
# its in-flight writes) before npm and caffeinate above it go away.
kill_tree() {
  local pid=$1 child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do kill_tree "$child"; done
  kill -TERM "$pid" 2>/dev/null || true
}

# The actual work. Runs inside caffeinate, detached from the terminal.
stages() {
  echo "=== harvest started $(date) ==="

  if [[ "$STAGE" == "all" || "$STAGE" == "rens" ]]; then
    echo; echo "--- [1/3] Ren's Pets (free) ---"
    run collect-rens --work "$WORK"
  fi

  if [[ "$STAGE" == "all" || "$STAGE" == "petsmart" ]]; then
    echo; echo "--- [2/3] PetSmart US + CA (free, throttled) ---"
    # collect-petsmart polls out an entry ban itself (up to 90 min) and rides out mid-run ones,
    # so exit 3 means the storefront stayed dark far longer than the usual window. Retry twice
    # more as a backstop, then move on rather than blocking the Pet Valu leg behind it.
    for attempt in 1 2 3; do
      set +e
      run collect-petsmart --storefront both --work "$WORK"
      code=$?
      set -e
      [[ $code -eq 0 ]] && break
      if [[ $code -ne 3 ]]; then echo "petsmart stopped (exit $code)"; break; fi
      echo "still blocked after the poll window; backstop retry $((attempt + 1)) in 30 min at $(date)"
      sleep 1800
    done
    # Stragglers (transient 5xx, truncated JSON) go through Firecrawl — usually a few dozen.
    run collect-petsmart --storefront both --via firecrawl --retry-failed --work "$WORK" || true
  fi

  if [[ "$STAGE" == "all" || "$STAGE" == "petvalu" ]]; then
    echo; echo "--- [3/3] Pet Valu (Firecrawl, brand-narrowed) ---"
    run collect-petvalu --budget "$PETVALU_BUDGET" --work "$WORK"
  fi

  if [[ "$STAGE" == "expand" || "$STAGE" == "intl" || "$STAGE" == "uk" ]]; then
    echo; echo "--- Pets at Home UK (Firecrawl, ~1 credit/product) ---"
    run collect-petsathome --budget "$INTL_BUDGET" --work "$WORK"
  fi

  if [[ "$STAGE" == "expand" || "$STAGE" == "intl" || "$STAGE" == "au" ]]; then
    echo; echo "--- Petbarn AU (Firecrawl, ~1 credit/product) ---"
    run collect-petbarn --budget "$INTL_BUDGET" --work "$WORK"
  fi

  if [[ "$STAGE" == "expand" || "$STAGE" == "petco" ]]; then
    echo; echo "--- Petco US (Firecrawl, ~1 credit/product) ---"
    run collect-petco --budget "$PETCO_BUDGET" --work "$WORK"
  fi

  # Every leg merges on the same terms as the domestic sweep, so they finish the way a full
  # run does rather than leaving rows stranded outside search.
  if [[ "$STAGE" == "expand" || "$STAGE" == "intl" ]]; then
    echo; echo "--- ingest + pack + group ---"
    run ingest --work "$WORK" --names "$RETAILER_HARVESTS"
    run pack
    run group --apply
  fi

  if [[ "$STAGE" == "all" ]]; then
    echo; echo "--- ingest + pack + group ---"
    run ingest --work "$WORK" --names "$RETAILER_HARVESTS"
    run pack
    # New rows arrive ungrouped and pack rebuilds products, so regroup last or search
    # silently loses the sizes this sweep just added.
    run group --apply
  fi

  echo; echo "=== harvest finished $(date) ==="
}

case "${1:-all}" in
  all|rens|petsmart|petvalu|expand|intl|uk|au|petco)
    if running; then
      echo "already running (pid $(cat "$PIDFILE")) — ./harvest.sh logs, or ./harvest.sh stop"
      exit 1
    fi
    export STAGE="${1:-all}"
    export -f stages run
    export WORK PETVALU_BUDGET INTL_BUDGET PETCO_BUDGET RETAILER_HARVESTS
    echo "starting '$1' detached; holding the machine awake for the duration."
    echo "  log:    $LOG"
    echo "  status: ./harvest.sh status"
    # nohup makes the job deaf to the HUP a closing terminal sends, and it is reparented to
    # launchd once this script exits.
    nohup bash -c stages >>"$LOG" 2>&1 &
    WORK_PID=$!
    echo "$WORK_PID" >"$PIDFILE"
    # Hold the machine awake for exactly as long as that pid lives — no longer.
    nohup caffeinate -dimsw "$WORK_PID" >/dev/null 2>&1 &
    disown -a 2>/dev/null || true
    sleep 1
    echo "pid $WORK_PID"
    ;;

  ingest)
    run ingest --work "$WORK" "${@:2}"
    ;;

  status)
    if running; then echo "RUNNING (pid $(cat "$PIDFILE"))"; else echo "not running"; fi
    echo
    for f in "$WORK"/*.status.json; do
      [[ -e "$f" ]] || { echo "no harvests yet"; break; }
      python3 - "$f" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
pct = 100 * s["done"] / max(1, s["total"])
line = f'{s["name"]:14s} {s["done"]:>6}/{s["total"]:<6} {pct:5.1f}%  records={s["records"]:<6} failed={s["failed"]} gone={s["gone"]}'
if s.get("etaMin") is not None:
    line += f'  eta={s["etaMin"]:.0f}m'
if s.get("blockedUntil"):
    line += f'  BLOCKED until {s["blockedUntil"]}'
print(line)
PY
    done
    echo
    tail -3 "$LOG" 2>/dev/null || true
    ;;

  logs)
    tail -f "$LOG"
    ;;

  stop)
    if running; then
      # SIGTERM: the harness stops taking new work, lets in-flight writes land, and exits.
      kill_tree "$(cat "$PIDFILE")"
      echo "stop signalled — ledgers stay valid; re-run the same command to resume."
    else
      echo "not running"
    fi
    rm -f "$PIDFILE"
    ;;

  *)
    echo "usage: ./harvest.sh [all|rens|petsmart|petvalu|expand|intl|uk|au|petco|ingest|status|logs|stop]"
    exit 2
    ;;
esac
