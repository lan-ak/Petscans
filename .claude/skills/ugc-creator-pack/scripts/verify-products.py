#!/usr/bin/env python3
"""Pick and verify products for PetScans UGC scripts.

Two modes:

  find   Search the catalog for products that make good UGC subjects —
         mass-market, filler-first, by-product high, preservatives/dyes present.

  check  For specific GTINs, report exactly what the app will render: the
         general score, the warning flags, and — critically — which allergens
         are SAFE to name on camera and which are traps.

The trap detection is the point. The matcher does not always display what the
label says, and a script built on the wrong assumption puts a word on screen
that is not on the bag. Two failure modes, both detected here:

  PHANTOM  the app shows an ingredient the label never mentions
           (e.g. "Animal Fat (...)" is displayed as "Chicken fat")
           -> naming this allergen on camera is a lie a viewer can catch

  ERASED   the label says it but the app won't flag it
           (e.g. "Chicken By-Product Meal" is stored as "Meat by products")
           -> the creator may read it aloud, but must not say the app flagged it

Usage:
  verify-products.py find  --species cat [--limit 25] [--min-flags 2]
  verify-products.py check 00023100143330 00829274513760 ...
  verify-products.py check --species dog --allergens corn,soy,wheat <gtin>...
"""

import argparse
import json
import re
import sqlite3
import subprocess
import sys
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
CATALOG = REPO / "PetScans" / "Data" / "catalog.sqlite"
INGREDIENTS = REPO / "PetScans" / "Data" / "ingredients.json"
MATCHKIT_DIR = REPO / "tools" / "matchkit"
MATCHKIT = MATCHKIT_DIR / ".build" / "release" / "matchkit"

DEFAULT_ALLERGENS = ["chicken", "beef", "corn", "soy", "wheat", "lamb",
                     "fish", "salmon", "turkey", "egg", "dairy", "rice"]

# Things worth flagging in a hook. Not exhaustive — matchkit is the authority
# on what actually renders; this list only drives `find`.
MARKERS = ["bha", "bht", "ethoxyquin", "menadione", "titanium dioxide",
           "sodium nitrite", "propyl gallate", "tbhq", "caramel color",
           "red 40", "yellow 5", "yellow 6", "blue 2"]


def die(msg):
    sys.exit(f"error: {msg}")


def ensure_matchkit():
    if MATCHKIT.exists():
        return
    print("building matchkit (first run only)...", file=sys.stderr)
    r = subprocess.run(["swift", "build", "-c", "release"],
                       cwd=MATCHKIT_DIR, capture_output=True, text=True)
    if r.returncode != 0 or not MATCHKIT.exists():
        die(f"could not build matchkit:\n{r.stderr[-800:]}")


def load_ingredients():
    data = json.loads(INGREDIENTS.read_text())
    items = data if isinstance(data, list) else data.get("ingredients", data)
    if isinstance(items, dict):
        items = list(items.values())
    return {i["id"]: i for i in items if "id" in i}


def decompress(blob):
    return zlib.decompress(blob, -15).decode("utf-8", "replace")


def explain(gtin):
    r = subprocess.run([str(MATCHKIT), "explain", "--gtin", gtin],
                       cwd=MATCHKIT_DIR, capture_output=True, text=True)
    return r.stdout


def parse_explain(out):
    """-> (total, flags, tokens) where tokens = [(rank, ing_id, label_text)]"""
    m = re.search(r"^total ([\d.]+)", out, re.M)
    total = float(m.group(1)) if m else None
    flags = sorted(set(re.findall(
        r"(info|warn|high|critical)\s+safety\s+Ingredient warning — (ing_\w+)", out)))
    tokens = []
    if "tokens:" in out:
        body = out.split("tokens:", 1)[1].split("\ntotal ", 1)[0]
        for line in body.strip().splitlines():
            mm = re.match(r"\s*(\d+)\s+\S+\s+(ing_[a-z0-9_]+)\s+(.*?)(?:\s+\d)?$", line)
            if mm:
                tokens.append((int(mm.group(1)), mm.group(2), mm.group(3).strip()))
    return total, flags, tokens


def risk_for(ing, species):
    rl = ing.get("riskLevel")
    if isinstance(rl, dict):
        return str(rl.get(species, "")).lower()
    return str(rl or "").lower()


def general_label(tokens, by_id, species):
    """Reproduce the app's label switch.

    `hasToxic` / `hasCaution` are computed over every matched ingredient, not
    just the ones that raise a warning flag — so walk all tokens. Toxic wins.
    Returns (label, [reasons]).
    """
    toxic, caution = [], []
    for _, ing_id, _ in tokens:
        ing = by_id.get(ing_id)
        if not ing:
            continue
        risk = risk_for(ing, species)
        name = ing.get("commonName", ing_id)
        if "toxic" in risk:
            toxic.append(name)
        elif "caution" in risk:
            caution.append(name)
    if toxic:
        return "AVOID", sorted(set(toxic))
    if caution:
        return "Caution", sorted(set(caution))
    return "(score band)", []


def dedupe(tokens):
    """Catalog rows often repeat the whole panel (multi-pack listings), which
    yields phantom ranks like #41 for an ingredient printed at #1. Keep the
    first occurrence of each (ingredient, label text) pair."""
    seen, out = set(), []
    for rank, ing_id, label_text in tokens:
        key = (ing_id, label_text.lower())
        if key in seen:
            continue
        seen.add(key)
        out.append((rank, ing_id, label_text))
    return out


def allergen_report(tokens, by_id, allergens):
    """For each allergen: verdict + the evidence behind it."""
    out = {}
    for a in allergens:
        hits = []
        for rank, ing_id, label_text in tokens:
            ing = by_id.get(ing_id)
            if not ing:
                continue
            shown = ing.get("commonName", "")
            if a in shown.lower():
                hits.append({"rank": rank, "shown": shown, "label": label_text,
                             "in_label": a in label_text.lower()})
        erased = [(r, t) for r, i, t in tokens
                  if a in t.lower() and a not in by_id.get(i, {}).get("commonName", "").lower()]
        if not hits:
            if erased:
                out[a] = {"verdict": "ERASED", "rank": min(r for r, _ in erased),
                          "hits": [], "erased": erased}
            continue
        phantom = [h for h in hits if not h["in_label"]]
        clean = [h for h in hits if h["in_label"]]
        if clean and not phantom:
            verdict = "SAFE"
        elif clean and phantom:
            verdict = "MIXED"
        else:
            verdict = "PHANTOM"
        out[a] = {"verdict": verdict, "rank": min(h["rank"] for h in hits),
                  "hits": hits, "erased": erased}
    return out


# ------------------------------------------------------------------- check

def cmd_check(args):
    ensure_matchkit()
    by_id = load_ingredients()
    con = sqlite3.connect(CATALOG)
    allergens = [a.strip().lower() for a in args.allergens.split(",")] \
        if args.allergens else DEFAULT_ALLERGENS

    for gtin in args.gtins:
        row = con.execute(
            "SELECT name, brand, species, category FROM products WHERE gtin=?",
            (gtin,)).fetchone()
        if not row:
            print(f"\n!! {gtin} — not in catalog\n")
            continue
        name, brand, species, category = row
        raw = decompress(con.execute(
            "SELECT ingredients FROM products WHERE gtin=?", (gtin,)).fetchone()[0])
        total, flags, tokens = parse_explain(explain(gtin))
        tokens = dedupe(tokens)
        rep = allergen_report(tokens, by_id, allergens)
        label, reasons = general_label(tokens, by_id, species)

        print(f"\n{'=' * 78}\n{name}")
        print(f"  {gtin}   {species}/{category}   brand: {brand}")
        print(f"  GENERAL: {total}  ·  LABEL: {label}")
        if label == "AVOID":
            print(f"    ^^ toxic for {species}s: {', '.join(reasons)} — this bag reads "
                  f"AVOID with no pet profile at all. Rare and worth a script.")
        elif reasons:
            shown = reasons[:6]
            print(f"    caution-level: {', '.join(shown)}"
                  f"{f' (+{len(reasons) - 6} more)' if len(reasons) > 6 else ''}")
        print(f"  FLAGS SHOWN: {', '.join(f'{s}:{i[4:]}' for s, i in flags) or 'none'}")
        first = [x.strip() for x in raw.split(",")[:8]]
        print(f"  FIRST 8: {', '.join(first)}")

        print("  ALLERGEN TRIGGERS (any match forces total 0 + 'Avoid'):")
        safe = [a for a, v in rep.items() if v["verdict"] == "SAFE"]
        for a, v in sorted(rep.items(), key=lambda kv: kv[1].get("rank", 99)):
            mark = {"SAFE": "  OK ", "PHANTOM": "  XX ", "MIXED": "  ~~ ",
                    "ERASED": "  -- "}[v["verdict"]]
            if v["verdict"] == "ERASED":
                r, t = v["erased"][0]
                print(f'{mark}{a:8} ERASED  — label says "{t[:40]}" at #{r}, but the app '
                      f"stores it generically. Do NOT say the app flagged {a}.")
                continue
            for h in v["hits"]:
                tag = "" if h["in_label"] else "   <-- NOT ON THE LABEL"
                print(f'{mark}{a:8} #{h["rank"]:<3} shows as "{h["shown"]}" '
                      f'from "{h["label"][:40]}"{tag}')
            # An allergen can fire cleanly from one token while another token
            # naming it is stored generically. The creator may still read that
            # second one aloud, so surface it either way.
            for r, t in v["erased"]:
                print(f'       {"":8} #{r:<3} label says "{t[:40]}" but the app '
                      f"stores it generically — readable aloud, not attributable")
        print(f"  --> SAFE TO NAME ON CAMERA: {', '.join(safe) if safe else 'NONE'}")


# -------------------------------------------------------------------- find

def cmd_find(args):
    by_id = load_ingredients()
    con = sqlite3.connect(CATALOG)
    rows = con.execute(
        "SELECT gtin,name,brand,ingredients FROM products "
        "WHERE category='food' AND species=?", (args.species,)).fetchall()

    scored = []
    for gtin, name, brand, blob in rows:
        raw = decompress(blob)
        low = raw.lower()
        if "by-product" not in low and "by product" not in low:
            continue
        first = raw.split(",")[0].strip().lower()
        if args.filler_first and not any(
                f in first for f in ("corn", "wheat", "meat by", "meat and bone", "water")):
            continue
        markers = [m for m in MARKERS
                   if re.search(r"\b" + m.replace(" ", r"\s"), low)]
        if len(markers) < args.min_flags:
            continue
        scored.append((len(markers), gtin, brand, name, markers, first))

    scored.sort(reverse=True)
    print(f"{len(scored)} candidates for species={args.species} "
          f"(>={args.min_flags} markers, by-product present)\n")
    for n, gtin, brand, name, markers, first in scored[:args.limit]:
        print(f"{n:>2} markers  {gtin}  {name[:66]}")
        print(f"            brand={brand}  first={first[:34]}")
        print(f"            {', '.join(markers)}")
    print("\nNext: verify-products.py check <gtin> ...  "
          "— `find` only reads the label text, `check` reads what the app renders.")


def main():
    if not CATALOG.exists():
        die(f"catalog not found at {CATALOG}")
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("find", help="search the catalog for UGC-worthy products")
    f.add_argument("--species", choices=["dog", "cat"], required=True)
    f.add_argument("--limit", type=int, default=25)
    f.add_argument("--min-flags", type=int, default=2)
    f.add_argument("--filler-first", action="store_true",
                   help="require a filler/by-product as ingredient #1")
    f.set_defaults(func=cmd_find)

    c = sub.add_parser("check", help="verify what the app renders for given GTINs")
    c.add_argument("gtins", nargs="+")
    c.add_argument("--allergens", help="comma-separated (default: common ones). "
                                       "Species is read from the catalog row.")
    c.set_defaults(func=cmd_check)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
