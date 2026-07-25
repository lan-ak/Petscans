/**
 * Chewy collection: Firecrawl discovery -> Bright Data PDP scrape -> new-only JSON.
 *
 * Produces the input file `enrich --source chewy` consumes. Three constraints, all found
 * by probing the live APIs, decide the shape:
 *
 *  1. The Bright Data Chewy dataset has NO discovery collector — `type=discover_new` is
 *     rejected with "Incorrect discovery collector id". It only collects by PDP url.
 *  2. Its filter API reads a pre-collected corpus, but returns an arbitrary slice and
 *     fails with NOT_ENOUGH_FUNDS past a few hundred records, so it can't be aimed at a
 *     specific product. collect-by-url can, and expands every size variant.
 *  3. Chewy category pages are 429-walled to plain fetches (robots.txt and the sitemaps
 *     are open, but the PDP sitemaps carry no category signal and bury the food among
 *     ~245k urls of toys and bowls). Firecrawl gets through; that's what it's here for.
 *
 * So: Firecrawl lists the category pages, Bright Data turns those urls into records
 * carrying the GTIN, and ingredients come later from the Firecrawl pass in enrich.ts.
 *
 * Nothing already held is re-collected. Urls are checked against the ledger BEFORE the
 * Bright Data call, because skipping after the fact still pays for the records. The
 * catalog itself can't answer "did we fetch this url" — it stores GTINs and, since the
 * image fix, real image urls rather than PDP links — hence the sidecar ledger. Returned
 * GTINs are then checked against the catalog as a second net, so a url that yields a new
 * variant of a known product still contributes only the genuinely new barcodes.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { canonical, isShippable } from './gtin';

const BD = 'https://api.brightdata.com/datasets/v3';
const DATASET = 'gd_ml870vpc2a2gjb7bs2';
const FC = 'https://api.firecrawl.dev/v1';

/**
 * Category listings for the dog/cat food + treat scope, both storefronts.
 *
 * US and CA share numeric category ids but not slugs (1537 is `dog-cookies-and-biscuits`
 * on US, `biscuits-crunchy-treats` on CA), so these are literal urls from Chewy's category
 * sitemap, not constructed. Both are worth collecting: they stock different pack sizes,
 * and a different pack size is a different GTIN — US ships 18/34/47-lb bags where CA ships
 * 397/227/794-g, so the two barcode sets barely overlap.
 */
export const US_CATEGORIES = [
  'https://www.chewy.com/b/dry-food-294', // Dog dry
  'https://www.chewy.com/b/wet-food-293', // Dog wet
  'https://www.chewy.com/b/dog-food-toppers-337', // Dog toppers
  'https://www.chewy.com/b/dry-food-388', // Cat dry
  'https://www.chewy.com/b/wet-food-389', // Cat wet
  'https://www.chewy.com/b/cat-food-toppers-392', // Cat toppers
  'https://www.chewy.com/b/dog-cookies-and-biscuits-1537', // Dog biscuits & crunchy
  'https://www.chewy.com/b/soft-dog-treats-1538', // Dog soft & chewy
  'https://www.chewy.com/b/soft-cat-treats-1553', // Cat soft & chewy
  'https://www.chewy.com/b/freeze-dried-cat-treats-11870', // Cat freeze-dried
  'https://www.chewy.com/b/lickable-cat-treats-2275', // Cat lickable
];

export const CA_CATEGORIES = [
  'https://www.chewy.com/ca/b/dry-food-294',
  'https://www.chewy.com/ca/b/wet-food-293',
  'https://www.chewy.com/ca/b/food-toppings-337',
  'https://www.chewy.com/ca/b/dry-food-388',
  'https://www.chewy.com/ca/b/wet-food-389',
  'https://www.chewy.com/ca/b/food-toppings-392',
  'https://www.chewy.com/ca/b/biscuits-crunchy-treats-1537',
  'https://www.chewy.com/ca/b/soft-chewy-treats-1538',
  'https://www.chewy.com/ca/b/soft-chewy-treats-1553',
  'https://www.chewy.com/ca/b/freeze-dried-treats-11870',
  'https://www.chewy.com/ca/b/lickable-treats-2275',
];

export function categoriesFor(storefront: 'us' | 'ca' | 'both'): string[] {
  if (storefront === 'us') return US_CATEGORIES;
  if (storefront === 'ca') return CA_CATEGORIES;
  // Interleave so a run cut short by --limit still samples both storefronts.
  const out: string[] = [];
  for (let i = 0; i < Math.max(US_CATEGORIES.length, CA_CATEGORIES.length); i++) {
    if (US_CATEGORIES[i]) out.push(US_CATEGORIES[i]);
    if (CA_CATEGORIES[i]) out.push(CA_CATEGORIES[i]);
  }
  return out;
}

/**
 * Pet-specialty / vet-channel brands. Chewy stocks these; Walmart (the catalog's source
 * scrape) largely doesn't, so the shipped catalog systematically lacks them — that's the gap
 * this run fills. The broad category lists above eventually reach these brands too, but only
 * after paginating past thousands of grocery-channel SKUs already in the catalog, paying
 * Bright Data for each. Brand-scoped discovery goes straight to the missing rows.
 *
 * Discovery is Chewy's own search (`/s?query=`), which Firecrawl returns real /dp/ links from;
 * `extractDpUrl` unwraps the sponsored ad-redirect links search pages are full of.
 */
export const SPECIALTY_BRANDS = [
  'royal canin',
  'hills science diet',
  'hills prescription diet',
  'purina pro plan veterinary diets',
  'orijen',
  'acana',
  'fromm',
  'wellness',
  'merrick',
  'ziwi',
  'stella and chewys',
  'instinct',
  'nutro',
  'eukanuba',
  'farmina',
  'open farm',
  'the honest kitchen',
  'weruva',
  'tiki',
  'nulo',
  'canidae',
];

function brandSearches(base: string): string[] {
  return SPECIALTY_BRANDS.map((b) => `${base}/s?query=${encodeURIComponent(b)}`);
}

export function brandSearchesFor(storefront: 'us' | 'ca' | 'both'): string[] {
  const us = brandSearches('https://www.chewy.com');
  const ca = brandSearches('https://www.chewy.com/ca');
  if (storefront === 'us') return us;
  if (storefront === 'ca') return ca;
  const out: string[] = [];
  for (let i = 0; i < SPECIALTY_BRANDS.length; i++) {
    out.push(us[i]);
    out.push(ca[i]);
  }
  return out;
}

/** Ad-hoc search urls for one free-text query, both storefronts — for targeting a specific
 *  product/brand on demand rather than walking the whole specialty list. */
export function searchUrlsFor(storefront: 'us' | 'ca' | 'both', term: string): string[] {
  const q = encodeURIComponent(term);
  const us = `https://www.chewy.com/s?query=${q}`;
  const ca = `https://www.chewy.com/ca/s?query=${q}`;
  if (storefront === 'us') return [us];
  if (storefront === 'ca') return [ca];
  return [us, ca];
}

/**
 * Pull the canonical `.../dp/<id>` url out of a Firecrawl link. Handles three shapes seen on
 * Chewy listing/search pages: a direct PDP link, a sponsored ad-redirect wrapper
 * (`/api/event/p/sar/click?...&redirect=<pdp>`), and percent-encoded variants of either.
 * Returns null for anything that isn't a product page (nav, facets, bowls-as-ads).
 */
const DP_RE = /https?:\/\/www\.chewy\.com\/(?:ca\/)?[a-z0-9-]+\/dp\/\d+/i;

export function extractDpUrl(link: string): string | null {
  let s = link;
  try {
    s = decodeURIComponent(link);
  } catch {
    /* malformed %-encoding: fall back to the raw string */
  }
  const m = s.match(DP_RE);
  return m ? m[0] : null;
}

/**
 * Scope test on a record's `product_category`.
 *
 * CA and US ship different taxonomies for the same product — "Dog > Food > Dry Food" vs
 * "Dog Supplies > Dog Food > Dry Dog Food". Matching either literal list would silently
 * drop a storefront, so this matches structurally: a dog/cat path about food or treats,
 * minus the non-consumables shelved under the same branches. It's a coarse net by design;
 * enrich's "no ingredients, no row" rule is what actually keeps bowls and mats out.
 */
const NON_CONSUMABLE = /\b(bowl|feeder|mat|toy|storage|container|scoop|dish|placemat|puzzle|costume|accessor)/i;

export function isTargetCategory(pc: string): boolean {
  const s = (pc || '').toLowerCase();
  if (!s) return false;
  if (NON_CONSUMABLE.test(s)) return false;
  const species = /\bdog\b|\bcat\b|\bpuppy\b|\bkitten\b|canada shop/.test(s);
  const kind = /\bfood\b|\btreat/.test(s);
  return species && kind;
}

/** Urls already sent to Bright Data, one per line. Kept out of the catalog so the shipped
 *  sqlite stays lean, and committed so the skip-list survives across machines. */
export function readLedger(path: string): Set<string> {
  if (!existsSync(path)) return new Set();
  return new Set(
    readFileSync(path, 'utf8')
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean),
  );
}

export function appendLedger(path: string, urls: string[]): void {
  if (!urls.length) return;
  mkdirSync(dirname(path), { recursive: true });
  const existing = readLedger(path);
  for (const u of urls) existing.add(u);
  writeFileSync(path, [...existing].sort().join('\n') + '\n');
}

async function fcLinks(key: string, url: string): Promise<string[]> {
  const r = await fetch(`${FC}/scrape`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ url, formats: ['links'] }),
  });
  const j = (await r.json().catch(() => ({}))) as { data?: { links?: string[] } };
  return j.data?.links ?? [];
}

/**
 * Harvest distinct /dp/ urls from the category listings, skipping anything in `skip`.
 * `pages` walks Chewy's ?page=N pagination. Stops once `limit` unseen urls are in hand.
 */
export async function discoverProductUrls(
  key: string,
  categories: string[],
  opts: { limit: number; pages?: number; skip?: Set<string>; onLog?: (s: string) => void },
): Promise<{ fresh: string[]; skipped: number }> {
  const log = opts.onLog ?? (() => {});
  const skip = opts.skip ?? new Set<string>();
  const pages = opts.pages ?? 1;
  const fresh = new Set<string>();
  let skipped = 0;

  // Page-major so a limited run spreads across categories instead of exhausting the first.
  for (let p = 1; p <= pages; p++) {
    for (const cat of categories) {
      if (fresh.size >= opts.limit) return { fresh: [...fresh].slice(0, opts.limit), skipped };
      // Category urls are bare (`?page=` works); brand-search urls already carry `?query=`
      // and need `&page=`.
      const url = p === 1 ? cat : `${cat}${cat.includes('?') ? '&' : '?'}page=${p}`;
      let links: string[] = [];
      try {
        links = await fcLinks(key, url);
      } catch {
        log(`  ! discover failed: ${url}`);
        continue;
      }
      const before = fresh.size;
      for (const l of links) {
        const clean = extractDpUrl(l);
        if (!clean) continue;
        if (skip.has(clean)) {
          skipped++;
          continue;
        }
        fresh.add(clean);
      }
      log(`  ${url} -> +${fresh.size - before} new (${fresh.size} total, ${skipped} already collected)`);
    }
  }
  return { fresh: [...fresh].slice(0, opts.limit), skipped };
}

/** POST the url batch, poll the snapshot, return the raw Chewy records. */
export async function collectViaBrightData(
  key: string,
  urls: string[],
  opts: { onLog?: (s: string) => void; pollMs?: number; maxPolls?: number } = {},
): Promise<Record<string, unknown>[]> {
  const log = opts.onLog ?? (() => {});
  const pollMs = opts.pollMs ?? 20000;
  const maxPolls = opts.maxPolls ?? 120;

  const trig = await fetch(`${BD}/trigger?dataset_id=${DATASET}&include_errors=true&format=json`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify(urls.map((url) => ({ url }))),
  });
  const tj = (await trig.json().catch(() => ({}))) as { snapshot_id?: string };
  if (!tj.snapshot_id) throw new Error(`trigger failed: ${JSON.stringify(tj)}`);
  const snap = tj.snapshot_id;
  log(`snapshot ${snap} — ${urls.length} urls submitted`);

  for (let i = 0; i < maxPolls; i++) {
    const pr = await fetch(`${BD}/progress/${snap}`, { headers: { Authorization: `Bearer ${key}` } });
    const pj = (await pr.json().catch(() => ({}))) as { status?: string; records?: number };
    if (pj.status === 'ready') {
      log(`  ready — ${pj.records ?? '?'} records`);
      break;
    }
    if (pj.status === 'failed') throw new Error(`snapshot ${snap} failed`);
    if (i % 3 === 0) log(`  poll ${i + 1}: ${pj.status ?? '?'}`);
    await new Promise((r) => setTimeout(r, pollMs));
  }

  // The downloadable file lags `ready`; the API says so explicitly, so retry on that.
  for (let i = 0; i < 10; i++) {
    const dl = await fetch(`${BD}/snapshot/${snap}?format=json`, { headers: { Authorization: `Bearer ${key}` } });
    const raw = (await dl.json().catch(() => null)) as unknown;
    if (Array.isArray(raw)) return raw as Record<string, unknown>[];
    if (raw && typeof raw === 'object' && (raw as { status?: string }).status === 'building') {
      await new Promise((r) => setTimeout(r, 15000));
      continue;
    }
    if (raw) return [raw as Record<string, unknown>];
  }
  throw new Error(`snapshot ${snap} never produced a downloadable file`);
}

export interface CollectResult {
  urlsDiscovered: number;
  urlsSkipped: number;
  recordsReturned: number;
  inScope: number;
  newGtins: number;
  alreadyHeld: number;
  outPath: string;
}

/**
 * Discover -> collect -> keep only in-scope records whose GTIN the catalog lacks.
 * Writes a Bright-Data-shaped JSON array that `enrich --source chewy` reads directly.
 */
export async function collectChewy(opts: {
  fcKey: string;
  bdKey: string;
  dbPath: string;
  ledgerPath: string;
  out: string;
  storefront: 'us' | 'ca' | 'both';
  pages: number;
  limit: number;
  /** 'categories' walks the broad food/treat listings; 'brands' targets the specialty-brand
   *  gap via Chewy search. Default 'categories'. */
  discovery?: 'categories' | 'brands';
  /** Ad-hoc free-text search term; overrides `discovery` to target one product/brand. */
  query?: string;
  /** Stop after Firecrawl discovery: write the url list, skip the paid Bright Data step, and
   *  DON'T touch the ledger. For confirming a scope finds what you expect before spending. */
  dryRun?: boolean;
  /** Skip discovery entirely and collect from a pre-discovered url list (a JSON array of dp
   *  urls, e.g. a prior --dry-run output). Lets a full sweep pay Firecrawl discovery ONCE, then
   *  batch the paid Bright Data collection from the static list (ledger-skip advances each run). */
  urlsFile?: string;
  onLog?: (s: string) => void;
}): Promise<CollectResult> {
  const log = opts.onLog ?? (() => {});

  const ledger = readLedger(opts.ledgerPath);
  log(`ledger: ${ledger.size} urls already collected`);

  let fresh: string[];
  let skipped: number;
  if (opts.urlsFile) {
    const all = JSON.parse(readFileSync(opts.urlsFile, 'utf8')) as string[];
    const unseen = all.filter((u) => !ledger.has(u));
    skipped = all.length - unseen.length;
    fresh = unseen.slice(0, opts.limit);
    log(`urls file: ${all.length} total, ${fresh.length} taken this batch (${skipped} already in ledger)`);
  } else {
    const sources = opts.query
      ? searchUrlsFor(opts.storefront, opts.query)
      : opts.discovery === 'brands'
        ? brandSearchesFor(opts.storefront)
        : categoriesFor(opts.storefront);
    log(`discovery: ${opts.query ? `query "${opts.query}"` : (opts.discovery ?? 'categories')} — ${sources.length} source urls`);
    const r = await discoverProductUrls(opts.fcKey, sources, {
      limit: opts.limit,
      pages: opts.pages,
      skip: ledger,
      onLog: log,
    });
    fresh = r.fresh;
    skipped = r.skipped;
    log(`discovered ${fresh.length} new urls (${skipped} skipped as already collected)`);
  }

  if (opts.dryRun) {
    mkdirSync(dirname(opts.out), { recursive: true });
    writeFileSync(opts.out, JSON.stringify(fresh, null, 2));
    log(`dry run: wrote ${fresh.length} urls to ${opts.out}; Bright Data NOT called, ledger untouched`);
    return {
      urlsDiscovered: fresh.length,
      urlsSkipped: skipped,
      recordsReturned: 0,
      inScope: 0,
      newGtins: 0,
      alreadyHeld: 0,
      outPath: opts.out,
    };
  }

  if (!fresh.length) {
    writeFileSync(opts.out, '[]');
    return {
      urlsDiscovered: 0,
      urlsSkipped: skipped,
      recordsReturned: 0,
      inScope: 0,
      newGtins: 0,
      alreadyHeld: 0,
      outPath: opts.out,
    };
  }

  const records = await collectViaBrightData(opts.bdKey, fresh, { onLog: log });

  // Record the attempt whatever came back: a url that yields nothing shouldn't be paid for
  // twice on the next run.
  appendLedger(opts.ledgerPath, fresh);

  const db = new DatabaseSync(opts.dbPath, { readOnly: true });
  const held = new Set<string>((db.prepare('SELECT gtin FROM products').all() as { gtin: string }[]).map((r) => r.gtin));
  db.close();

  const kept = new Map<string, Record<string, unknown>>();
  let inScope = 0;
  let alreadyHeld = 0;
  for (const r of records) {
    if (!isTargetCategory(String(r.product_category ?? ''))) continue;
    inScope++;
    const g = canonical(String(r.gtin ?? ''));
    if (!g || !isShippable(g)) continue;
    if (held.has(g)) {
      alreadyHeld++;
      continue;
    }
    if (!kept.has(g)) kept.set(g, r);
  }

  mkdirSync(dirname(opts.out), { recursive: true });
  writeFileSync(opts.out, JSON.stringify([...kept.values()]));

  return {
    urlsDiscovered: fresh.length,
    urlsSkipped: skipped,
    recordsReturned: records.length,
    inScope,
    newGtins: kept.size,
    alreadyHeld,
    outPath: opts.out,
  };
}
