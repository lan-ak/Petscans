/**
 * Guaranteed-analysis backfill for catalog rows that have none.
 *
 * The retailer sweeps supply macros for free wherever they touch a product, but they only reach
 * what those retailers list. Everything else — most of the Walmart-sourced bulk of the catalog —
 * has to be looked up one product at a time: search the label, read the analysis off the best
 * result.
 *
 * Deliberately budget-capped rather than exhaustive. At roughly 3 credits a product a full sweep
 * of the ~31k rows without macros would cost far more than a month's plan, so targets come out
 * biggest-brand-first: the brands with the most rows are the ones a scan is most likely to hit,
 * so a partial backfill bought in that order is worth much more than the same spend scattered.
 *
 * The page is read as markdown and parsed, not handed to an extraction schema. AAFCO wording is
 * fixed enough to match ("Crude Protein (Min.) 24 %"), which makes this a fifth of the price and
 * removes the truncation the extractor showed on ingredient lists (see intl.ts).
 */

import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { BlockedError, GoneError, type HarvestRecord } from './harvest';
import { ANALYSIS_COLUMNS, parseAnalysisText, type Analysis } from './analysis';

const FC = 'https://api.firecrawl.dev/v2';

/** Marketplace and aggregator hosts that restate a label badly, or not at all. */
const BAD_HOST = /amazon\.|ebay\.|pinterest\.|reddit\.|youtube\.|facebook\.|alibaba\.|aliexpress\.|walmart\./i;

export interface AnalysisTarget {
  gtin: string;
  brand: string;
  name: string;
}

/**
 * Rows with no macros, biggest brands first. `protein_pct` stands in for the whole set: it is
 * the field every label states, so a row without it has nothing useful in the other columns.
 */
export function productsWithoutAnalysis(dbPath: string, limit?: number): AnalysisTarget[] {
  const db = new DatabaseSync(dbPath, { readOnly: true });

  /**
   * The macro columns may not exist — a `git checkout` of the catalog puts it back to a schema
   * that predates them, which is exactly what happened once mid-run while someone else was
   * holding the catalog at HEAD as a scoring baseline. Treat their absence as "no row has
   * macros" rather than adding them, so this stays a pure reader and never writes to a file
   * another person is using.
   */
  const hasMacros = (db.prepare('PRAGMA table_info(products)').all() as { name: string }[]).some(
    (c) => c.name === 'protein_pct',
  );
  const missing = hasMacros ? 'p.protein_pct IS NULL' : '1=1';

  const rows = db
    .prepare(
      `SELECT p.gtin, p.brand, p.name
         FROM products p
         JOIN (SELECT brand, COUNT(*) n FROM products GROUP BY brand) b ON b.brand = p.brand
        WHERE ${missing}
        ORDER BY b.n DESC, p.brand, p.gtin
        ${limit ? 'LIMIT ?' : ''}`,
    )
    .all(...(limit ? [limit] : [])) as unknown as AnalysisTarget[];
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
  const j = (await r.json().catch(() => ({}))) as { data?: { web?: { url?: string }[] } | { url?: string }[] };
  const list = Array.isArray(j.data) ? j.data : (j.data?.web ?? []);
  return list.map((d) => d.url ?? '').filter(Boolean);
}

async function markdown(key: string, url: string): Promise<string> {
  const r = await fetch(`${FC}/scrape`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ url, formats: ['markdown'], onlyMainContent: true, timeout: 45_000 }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (r.status === 429) throw new BlockedError(60_000, 'firecrawl rate limit');
  if (!r.ok) return '';
  const j = (await r.json().catch(() => ({}))) as { data?: { markdown?: string } };
  return j.data?.markdown ?? '';
}

export function fetchAnalysis(key: string) {
  return async (t: AnalysisTarget): Promise<HarvestRecord[]> => {
    const results = await search(key, `${t.brand} ${t.name} guaranteed analysis`.replace(/\s+/g, ' ').slice(0, 140));
    const candidates = results.filter((u) => !BAD_HOST.test(u)).slice(0, 2);
    if (!candidates.length) throw new GoneError('no usable search result');

    for (const url of candidates) {
      const a = parseAnalysisText(await markdown(key, url));
      if (a) {
        return [
          {
            gtin: t.gtin,
            brand: t.brand,
            name: t.name,
            ingredients: '',
            source: 'analysis-backfill',
            analysis: Object.fromEntries(Object.entries(a).map(([k, v]) => [k, String(v)])),
          },
        ];
      }
    }
    throw new GoneError('no guaranteed analysis on any candidate');
  };
}

export interface ApplyAnalysisResult {
  read: number;
  updated: number;
  unusable: number;
}

/**
 * Write the harvested macros onto the catalog. COALESCE for the same reason ingest uses it: a
 * column already filled by a retailer sweep is better evidence than a search result, and must
 * not be overwritten by one.
 */
export function applyAnalysis(jsonlPath: string, dbPath: string): ApplyAnalysisResult {
  const res: ApplyAnalysisResult = { read: 0, updated: 0, unusable: 0 };
  const db = new DatabaseSync(dbPath);
  const sets = ANALYSIS_COLUMNS.map(([, col]) => `${col} = COALESCE(${col}, ?)`).join(', ');
  const update = db.prepare(`UPDATE products SET ${sets} WHERE gtin = ?`);

  db.exec('BEGIN');
  for (const line of readFileSync(jsonlPath, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    res.read++;
    const rec = JSON.parse(line) as HarvestRecord;
    const raw = rec.analysis;
    if (!raw) {
      res.unusable++;
      continue;
    }
    const a: Analysis = Object.fromEntries(
      Object.entries(raw).map(([k, v]) => [k, Number(v)]).filter(([, v]) => Number.isFinite(v as number)),
    ) as Analysis;
    if (!Object.keys(a).length) {
      res.unusable++;
      continue;
    }
    const values = ANALYSIS_COLUMNS.map(([field]) => a[field] ?? null);
    if (update.run(...values, rec.gtin).changes) res.updated++;
  }
  db.exec('COMMIT');
  db.close();
  return res;
}
