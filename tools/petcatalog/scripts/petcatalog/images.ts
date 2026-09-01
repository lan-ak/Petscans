/**
 * Image backfill for catalog rows that have none.
 *
 * 659 products ship with an empty `image_url`, overwhelmingly Walmart marketplace rows whose
 * listing carried no usable picture. They scan and score correctly; they just look broken in
 * the app's result list, which is the one place a user actually sees the row.
 *
 * These GTINs are, by definition, the ones the retailer sweeps do not reach — the sweeps insert
 * by GTIN and `ingest` is INSERT OR IGNORE, so an existing imageless row is never revisited by
 * a later Petco or Chewy pass. They have to be looked up individually: search the brand and
 * name, then read `og:image` off the best non-marketplace result. Search is ~2 credits and a
 * rawHtml scrape 1, so the whole backfill is ~2,000 credits.
 *
 * `og:image` rather than an extraction schema on purpose — it is a single meta tag, always
 * present on a real PDP, and costs a fifth as much to read. See intl.ts for the same argument
 * at greater length.
 */

import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { BlockedError, GoneError, type HarvestRecord } from './harvest';

const FC = 'https://api.firecrawl.dev/v2';

/** Hosts whose images are watermarked, generic, or hotlink-blocked. */
const BAD_HOST = /amazon\.|ebay\.|pinterest\.|reddit\.|youtube\.|facebook\.|alibaba\.|aliexpress\./i;

/**
 * An `og:image` that is chrome rather than the product. `share`/`banner` matter as much as
 * `logo`: a retailer whose PDP has no picture often falls back to a social-share card, and
 * three different Purina Beyond products all resolved to the same Instacart share banner.
 */
const BAD_IMAGE = /logo|placeholder|no[-_]?image|sprite|favicon|default|share[-_]?banner|social[-_]?share|opengraph|og[-_]?default/i;

export interface ImageTarget {
  gtin: string;
  brand: string;
  name: string;
}

/** Catalog rows with no picture. */
export function imagelessProducts(dbPath: string, limit?: number): ImageTarget[] {
  const db = new DatabaseSync(dbPath, { readOnly: true });
  const rows = db
    .prepare(
      `SELECT gtin, brand, name FROM products
       WHERE image_url IS NULL OR image_url = ''
       ORDER BY gtin ${limit ? 'LIMIT ?' : ''}`,
    )
    .all(...(limit ? [limit] : [])) as unknown as ImageTarget[];
  db.close();
  return rows;
}

async function search(key: string, query: string): Promise<string[]> {
  const r = await fetch(`${FC}/search`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ query, limit: 5 }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (r.status === 429) throw new BlockedError(60_000, 'firecrawl rate limit');
  // v2 returns `data` as an object of result groups (`{web:[...]}`), where v1 returned a bare
  // array — enrich.ts still talks to v1, so the two parsers differ on purpose.
  const j = (await r.json().catch(() => ({}))) as { data?: { web?: { url?: string }[] } | { url?: string }[] };
  const list = Array.isArray(j.data) ? j.data : (j.data?.web ?? []);
  return list.map((d) => d.url ?? '').filter(Boolean);
}

async function ogImage(key: string, url: string): Promise<string | null> {
  const r = await fetch(`${FC}/scrape`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ url, formats: ['rawHtml'], timeout: 45_000 }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (r.status === 429) throw new BlockedError(60_000, 'firecrawl rate limit');
  if (!r.ok) return null;
  const j = (await r.json().catch(() => ({}))) as { data?: { rawHtml?: string; metadata?: Record<string, unknown> } };

  const meta = j.data?.metadata ?? {};
  const fromMeta = (meta['ogImage'] ?? meta['og:image']) as string | undefined;
  const html = j.data?.rawHtml ?? '';
  const fromHtml =
    html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)?.[1] ??
    html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i)?.[1];

  const img = (fromMeta || fromHtml || '').trim();
  if (!img || !/^https?:\/\//.test(img) || BAD_IMAGE.test(img)) return null;
  return img;
}

/**
 * One product -> one record carrying the image. The record is shaped as a HarvestRecord purely
 * so the existing resumable harness drives it; `ingest` must never be pointed at this harvest,
 * because `ingredients` is a placeholder. `apply-images` is what consumes it.
 */
export function fetchImage(key: string) {
  return async (t: ImageTarget): Promise<HarvestRecord[]> => {
    const results = await search(key, `${t.brand} ${t.name}`.replace(/\s+/g, ' ').slice(0, 120));
    const candidates = results.filter((u) => !BAD_HOST.test(u));
    if (!candidates.length) throw new GoneError('no usable search result');

    for (const url of candidates.slice(0, 2)) {
      const img = await ogImage(key, url);
      if (img) return [{ gtin: t.gtin, brand: t.brand, name: t.name, ingredients: '', image: img, source: 'image-backfill' }];
    }
    throw new GoneError('no og:image on any candidate');
  };
}

export interface ApplyResult {
  read: number;
  updated: number;
  skippedNoImage: number;
  missingRow: number;
}

/** Write the harvested images onto the catalog. Only ever fills a blank — never overwrites. */
export function applyImages(jsonlPath: string, dbPath: string): ApplyResult {
  const res: ApplyResult = { read: 0, updated: 0, skippedNoImage: 0, missingRow: 0 };
  const db = new DatabaseSync(dbPath);
  const update = db.prepare(`UPDATE products SET image_url = ? WHERE gtin = ? AND (image_url IS NULL OR image_url = '')`);

  // A real PDP image belongs to exactly one product. An image url claimed by several is a
  // share card or category banner that slipped past BAD_IMAGE, so drop every use of it rather
  // than pick a winner.
  const lines = readFileSync(jsonlPath, 'utf8').split('\n').filter((l) => l.trim());
  const uses = new Map<string, number>();
  for (const l of lines) {
    const img = (JSON.parse(l) as HarvestRecord).image;
    if (img) uses.set(img, (uses.get(img) ?? 0) + 1);
  }

  for (const line of lines) {
    res.read++;
    const rec = JSON.parse(line) as HarvestRecord;
    if (!rec.image || (uses.get(rec.image) ?? 0) > 1) {
      res.skippedNoImage++;
      continue;
    }
    const r = update.run(rec.image, rec.gtin);
    if (r.changes) res.updated++;
    else res.missingRow++;
  }
  db.close();
  return res;
}
