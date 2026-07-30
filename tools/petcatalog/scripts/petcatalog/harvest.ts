/**
 * Resumable harvest harness — the part that survives a closed lid.
 *
 * A retailer sweep is 3,000-8,000 HTTP fetches over an hour or more, on a laptop that will
 * sleep, lose wifi, or get its terminal closed mid-run. So nothing here is held in memory
 * longer than one item: every record is appended to a JSONL file the instant it is fetched,
 * and the item's id is appended to a `.done` ledger immediately after. Re-running the same
 * command reads the ledger and skips what it already has, so a hard kill costs at most the
 * handful of items in flight.
 *
 * The ordering (records first, then ledger) is deliberate. A crash between the two re-fetches
 * one item and writes it twice; `ingest` keys on GTIN and INSERT OR IGNOREs, so a duplicate
 * line is free. The reverse order would silently drop a product.
 *
 * Sleep looks exactly like a network partition: every socket dies at once, then works again
 * minutes later. Transient failures therefore retry with backoff rather than aborting, and a
 * whole-run pause (`BlockedError`) parks every worker on a shared gate instead of burning the
 * queue against a wall — PetSmart's Akamai bans an IP for ~45 minutes once it decides you are
 * a bot, and the only correct response is to wait it out.
 */

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

/** One product ready for the `extract` cascade. Written verbatim as a JSONL line. */
export interface HarvestRecord {
  gtin: string;
  brand: string;
  name: string;
  /** Raw ingredient text. Tokenised later by extract(), so scrape debris is fine here. */
  ingredients: string;
  image?: string;
  /** Feeds species/treat inference in extract(). Must contain the words 'dog' or 'cat'. */
  categoryPath?: string;
  source: string;
}

/** Throw from a fetcher to park the entire run — the host is refusing everyone, not this item. */
export class BlockedError extends Error {
  constructor(public readonly retryAfterMs: number, message = 'blocked by host') {
    super(message);
    this.name = 'BlockedError';
  }
}

/** Throw to record the item as permanently unavailable (404) — ledgered, never retried. */
export class GoneError extends Error {
  constructor(message = 'gone') {
    super(message);
    this.name = 'GoneError';
  }
}

export interface HarvestOptions<T> {
  /** Basename for the three sidecar files: <name>.jsonl, <name>.done, <name>.failed. */
  name: string;
  workDir: string;
  targets: T[];
  idOf: (t: T) => string;
  /** Return the records for one target. Throw BlockedError/GoneError for the two special cases. */
  fetchOne: (t: T) => Promise<HarvestRecord[]>;
  concurrency?: number;
  /** Per-worker pause between requests. Rate ≈ concurrency / delayMs. */
  delayMs?: number;
  /** Attempts per item before it lands in <name>.failed. */
  attempts?: number;
  onLog?: (s: string) => void;
}

export interface HarvestResult {
  total: number;
  skippedFromLedger: number;
  fetched: number;
  records: number;
  failed: number;
  gone: number;
  blockedPauses: number;
  jsonlPath: string;
  failedPath: string;
  stopped: boolean;
}

export const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

/**
 * Ids a previous run already collected, for callers that must budget before dispatch.
 *
 * `harvest` applies this itself; this is for the paid sources, where a spend ceiling has to be
 * measured against what is actually left to fetch rather than the whole target list — capping
 * first would spend the budget counting work already done.
 */
export function readDone(workDir: string, name: string): Set<string> {
  return readLedger(resolve(workDir, `${name}.done`));
}

/** Ids already collected. Missing file = fresh run. */
function readLedger(path: string): Set<string> {
  if (!existsSync(path)) return new Set();
  return new Set(
    readFileSync(path, 'utf8')
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

/**
 * A gate every worker awaits before each request. Closed by the first worker to hit a
 * BlockedError, reopened once the ban window elapses — so a block costs one wait, not one
 * wait per worker.
 */
class Gate {
  private open: Promise<void> | null = null;
  private release: (() => void) | null = null;
  closedUntil = 0;
  pauses = 0;

  async wait(): Promise<void> {
    while (this.open) await this.open;
  }

  /** Idempotent: a second worker arriving inside the same ban window just waits. */
  async close(ms: number, onLog: (s: string) => void): Promise<void> {
    if (this.open) {
      await this.open;
      return;
    }
    this.pauses++;
    this.closedUntil = Date.now() + ms;
    this.open = new Promise<void>((r) => (this.release = r));
    onLog(`  ⏸ blocked by host — pausing ${(ms / 60000).toFixed(0)} min (resumes ${new Date(this.closedUntil).toLocaleTimeString()})`);
    await sleep(ms);
    const rel = this.release;
    this.open = null;
    this.release = null;
    this.closedUntil = 0;
    rel?.();
    onLog('  ▶ resuming');
  }
}

/**
 * Run `fetchOne` across every target that isn't already in the ledger, appending as it goes.
 *
 * Safe to invoke repeatedly with the same name/workDir: that is the resume path.
 */
export async function harvest<T>(opts: HarvestOptions<T>): Promise<HarvestResult> {
  const log = opts.onLog ?? (() => {});
  const conc = Math.max(1, opts.concurrency ?? 4);
  const delayMs = opts.delayMs ?? 0;
  const maxAttempts = opts.attempts ?? 3;

  mkdirSync(opts.workDir, { recursive: true });
  const jsonlPath = resolve(opts.workDir, `${opts.name}.jsonl`);
  const donePath = resolve(opts.workDir, `${opts.name}.done`);
  const failedPath = resolve(opts.workDir, `${opts.name}.failed`);
  const statusPath = resolve(opts.workDir, `${opts.name}.status.json`);

  const done = readLedger(donePath);
  const queue = opts.targets.filter((t) => !done.has(opts.idOf(t)));

  const res: HarvestResult = {
    total: opts.targets.length,
    skippedFromLedger: opts.targets.length - queue.length,
    fetched: 0,
    records: 0,
    failed: 0,
    gone: 0,
    blockedPauses: 0,
    jsonlPath,
    failedPath,
    stopped: false,
  };

  log(`${opts.name}: ${queue.length} to fetch (${res.skippedFromLedger} already in ledger of ${res.total})`);
  if (!queue.length) return res;

  const gate = new Gate();
  const started = Date.now();
  let stop = false;
  let cursor = 0;

  // Ctrl-C / `kill` should look exactly like a power cut: stop taking new work, let the
  // in-flight writes land, print the resume line. Everything already on disk stays valid.
  const onSignal = (sig: string) => {
    if (stop) process.exit(130);
    stop = true;
    res.stopped = true;
    log(`\n${sig} — draining in-flight fetches; re-run the same command to resume.`);
  };
  process.on('SIGINT', () => onSignal('SIGINT'));
  process.on('SIGTERM', () => onSignal('SIGTERM'));

  const writeStatus = (): void => {
    const elapsed = (Date.now() - started) / 1000;
    const rate = res.fetched / Math.max(1, elapsed);
    writeFileSync(
      statusPath,
      JSON.stringify(
        {
          name: opts.name,
          pid: process.pid,
          total: res.total,
          done: res.skippedFromLedger + res.fetched + res.gone,
          fetched: res.fetched,
          records: res.records,
          failed: res.failed,
          gone: res.gone,
          blockedPauses: gate.pauses,
          blockedUntil: gate.closedUntil ? new Date(gate.closedUntil).toISOString() : null,
          ratePerSec: Number(rate.toFixed(2)),
          etaMin: rate > 0 ? Number(((queue.length - res.fetched) / rate / 60).toFixed(1)) : null,
          updatedAt: new Date().toISOString(),
        },
        null,
        2,
      ),
    );
  };

  async function worker(): Promise<void> {
    while (!stop) {
      const idx = cursor++;
      if (idx >= queue.length) return;
      const target = queue[idx];
      const id = opts.idOf(target);

      await gate.wait();

      let records: HarvestRecord[] | null = null;
      let lastErr = '';
      for (let a = 0; a < maxAttempts && !stop; a++) {
        try {
          records = await opts.fetchOne(target);
          break;
        } catch (err) {
          if (err instanceof BlockedError) {
            await gate.close(err.retryAfterMs, log);
            a--; // a block is not this item's fault — don't spend an attempt on it
            continue;
          }
          if (err instanceof GoneError) {
            res.gone++;
            appendFileSync(donePath, id + '\n'); // 404s are permanent; never look again
            records = null;
            lastErr = '';
            break;
          }
          lastErr = err instanceof Error ? `${err.name}: ${err.message}` : String(err);
          // Sleep/wifi-drop shows up here. Back off and try again rather than giving up.
          if (a < maxAttempts - 1) await sleep(1000 * (a + 1) * (a + 1));
        }
      }

      if (records) {
        // Records first, ledger second — see the file header for why this order.
        if (records.length) {
          appendFileSync(jsonlPath, records.map((r) => JSON.stringify(r)).join('\n') + '\n');
          res.records += records.length;
        }
        appendFileSync(donePath, id + '\n');
        res.fetched++;
      } else if (lastErr) {
        res.failed++;
        appendFileSync(failedPath, `${id}\t${lastErr}\n`);
      }

      if ((res.fetched + res.failed + res.gone) % 25 === 0) {
        writeStatus();
        const seen = res.fetched + res.failed + res.gone;
        log(`  ${seen}/${queue.length}  records=${res.records}  failed=${res.failed}  gone=${res.gone}`);
      }
      if (delayMs) await sleep(delayMs);
    }
  }

  await Promise.all(Array.from({ length: conc }, () => worker()));
  res.blockedPauses = gate.pauses;
  writeStatus();
  return res;
}

/** Read back everything a harvest wrote. Tolerates the truncated last line of a killed run. */
export function readHarvest(workDir: string, name: string): HarvestRecord[] {
  const path = resolve(workDir, `${name}.jsonl`);
  if (!existsSync(path)) return [];
  const out: HarvestRecord[] = [];
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const s = line.trim();
    if (!s) continue;
    try {
      out.push(JSON.parse(s) as HarvestRecord);
    } catch {
      // a kill mid-append can leave one partial line; the item is not in the ledger, so
      // the next run re-fetches it.
    }
  }
  return out;
}

/** Ids in <name>.failed — the input to a `--retry-failed` pass. */
export function readFailed(workDir: string, name: string): string[] {
  const path = resolve(workDir, `${name}.failed`);
  if (!existsSync(path)) return [];
  return [
    ...new Set(
      readFileSync(path, 'utf8')
        .split('\n')
        .map((l) => l.split('\t')[0].trim())
        .filter(Boolean),
    ),
  ];
}

/** Drop the failed list — call once its ids have been re-queued, so it only ever holds live failures. */
export function clearFailed(workDir: string, name: string): void {
  const path = resolve(workDir, `${name}.failed`);
  if (existsSync(path)) writeFileSync(path, '');
}

export interface FetchOpts {
  timeoutMs?: number;
  headers?: Record<string, string>;
  /** Status codes that mean "the host is banning us", not "this item is broken". */
  blockOn?: number[];
  blockBackoffMs?: number;
}

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/** GET → text, mapping 404 to GoneError and the host's ban codes to BlockedError. */
export async function fetchText(url: string, opts: FetchOpts = {}): Promise<string> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), opts.timeoutMs ?? 45_000);
  try {
    const r = await fetch(url, {
      signal: ac.signal,
      headers: { 'User-Agent': UA, Accept: 'application/json, text/plain, */*', ...opts.headers },
    });
    if (r.status === 404 || r.status === 410) throw new GoneError(`HTTP ${r.status}`);
    if ((opts.blockOn ?? []).includes(r.status)) {
      throw new BlockedError(opts.blockBackoffMs ?? 45 * 60_000, `HTTP ${r.status}`);
    }
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.text();
  } finally {
    clearTimeout(t);
  }
}

export async function fetchJson<T>(url: string, opts: FetchOpts = {}): Promise<T> {
  return JSON.parse(await fetchText(url, opts)) as T;
}

/** Every <loc> in a sitemap or sitemap index. */
export async function sitemapLocs(url: string): Promise<string[]> {
  const xml = await fetchText(url, { timeoutMs: 90_000 });
  return [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim());
}

/** Ensure a directory exists for a file path. */
export function ensureDirFor(path: string): void {
  mkdirSync(dirname(path), { recursive: true });
}
