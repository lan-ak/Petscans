/**
 * Harvest JSONL → catalog.sqlite.
 *
 * The retailer adapters return complete products — GTIN, brand, name, ingredients, image — so
 * unlike the Chewy/Shopify path there is nothing left to enrich and no Firecrawl spend here.
 * What there still is, is the filter cascade: these rows go through the same `extract()` as the
 * vendor delivery, so a Ren's row is held to the identical standard as a Walmart one (valid
 * retail GTIN, ≥5 real ingredients, unambiguous species, English, no EU vague labelling).
 *
 * Ordering matters when the same product shows up at several retailers, which ~9% do. We keep
 * the deepest ingredient list rather than the first seen: PetSmart truncates some labels that
 * Ren's publishes in full, and vice versa, and the longer list is always the better score.
 */

import { DatabaseSync } from 'node:sqlite';
import { extract, type CatalogRow, type RejectReason } from './extract';
import { packIngredients } from './pack';
import { readHarvest, type HarvestRecord } from './harvest';
import { ANALYSIS_COLUMNS, ensureAnalysisColumns, parseAnalysis, type Analysis } from './analysis';

export interface IngestResult {
  read: number;
  rejected: Record<string, number>;
  candidates: number;
  alreadyHeld: number;
  /** Harvested rows whose brand string was folded onto the catalog's existing spelling. */
  brandsFolded: number;
  /** Net-new but too thin to ship (5-9 ingredients). Counted, never written. */
  tierC: number;
  /** True when the catalog carries size-variant grouping, so search depends on it. */
  grouped: boolean;
  /** Rows with no group_id — scannable, but invisible to search until `group --apply`. */
  ungrouped: number;
  inserted: number;
  /** Rows given macros they did not have — new inserts and existing rows both count. */
  analysisWritten: number;
  /** True when this run had to add the analysis columns. */
  analysisMigrated: boolean;
  bySource: Record<string, number>;
  topNewBrands: [string, number][];
  countBefore: number;
  countAfter: number;
}

/**
 * Retailers spell the same brand differently — Ren's ships "Science Diet" where the catalog
 * already holds 577 products under "Hill's Science Diet", PetSmart files Inaba's Churu line
 * under "Churu". Left alone, each variant becomes a second brand in a column the app shows to
 * users and groups by, so the same maker appears twice in one list.
 *
 * Most collisions are punctuation and fold out under normalisation (Benny Bullys / Benny
 * Bully's, Stella & Chewy's / Stella and Chewys). The table below is only for the ones that
 * do not: a retailer using a sub-brand or product line where the catalog uses the parent.
 * Keep it short and evidence-backed — over-folding merges two genuinely different makers.
 */
const BRAND_ALIAS: Record<string, string> = {
  'science diet': "hill's science diet",
  'prescription diet': "hill's prescription diet",
  churu: 'inaba',
  'ziwi peak': 'ziwi',
};

function normalizeBrand(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[''`]/g, '')
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9 ]+/g, ' ')
    .replace(/\b(pet ?foods?|brands?|inc|llc|ltd)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Fold a harvested brand onto the catalog's existing spelling when they name the same maker. */
function canonicalBrand(raw: string, held: Map<string, string>): string {
  const n = normalizeBrand(raw);
  const aliased = BRAND_ALIAS[n];
  if (aliased) {
    const hit = held.get(normalizeBrand(aliased));
    if (hit) return hit;
  }
  return held.get(n) ?? raw;
}

/** Shape a HarvestRecord into the row `extract()` expects, reusing every existing rule. */
function toVendorRow(r: HarvestRecord): Record<string, unknown> {
  return {
    gtin: r.gtin,
    brand: r.brand,
    product_name: r.name,
    main_image: r.image ?? '',
    category_path: r.categoryPath ?? '',
    // extract() parses this field as the vendor's JSON block list; matching that shape means
    // the ingredient text takes the same cleaning path as the delivered data.
    ingredients_full: JSON.stringify([{ type: 'Ingredients', values: r.ingredients }]),
  };
}

export function ingest(opts: {
  workDir: string;
  names: string[];
  dbPath: string;
  dryRun?: boolean;
  onLog?: (s: string) => void;
}): IngestResult {
  const log = opts.onLog ?? (() => {});

  const rejected: Record<string, number> = {};
  const best = new Map<string, { row: CatalogRow; source: string; analysis: Analysis | null }>();
  let read = 0;

  // Existing spellings, keyed by their normalised form, so harvested brands can fold onto them.
  const brandDb = new DatabaseSync(opts.dbPath);
  const heldBrands = new Map<string, string>();
  for (const { brand } of brandDb
    .prepare("SELECT DISTINCT trim(brand) brand FROM products WHERE brand IS NOT NULL AND trim(brand) <> ''")
    .all() as { brand: string }[]) {
    const n = normalizeBrand(brand);
    // Longest spelling wins: "Hill's Science Diet" is the useful label, "Science Diet" is not.
    if (!heldBrands.has(n) || brand.length > (heldBrands.get(n) as string).length) heldBrands.set(n, brand);
  }
  brandDb.close();
  let brandsFolded = 0;

  for (const name of opts.names) {
    const records = readHarvest(opts.workDir, name);
    log(`${name}: ${records.length} harvested records`);
    for (const rec of records) {
      read++;
      const result = extract(toVendorRow(rec));
      if (typeof result === 'string') {
        rejected[result as RejectReason] = (rejected[result as RejectReason] ?? 0) + 1;
        continue;
      }
      const folded = canonicalBrand(result.brand, heldBrands);
      if (folded !== result.brand) {
        brandsFolded++;
        result.brand = folded;
      }
      const held = best.get(result.gtin);
      // Deepest ingredient list wins — see the file header.
      if (held && held.row.nIngredients >= result.nIngredients) continue;
      best.set(result.gtin, { row: result, source: rec.source, analysis: parseAnalysis(rec.analysis) });
    }
  }

  const db = new DatabaseSync(opts.dbPath);
  // The columns have to exist before anything tries to write them, and a dry run must not
  // alter the schema it is only reporting on.
  const analysisMigrated = opts.dryRun ? false : ensureAnalysisColumns(db);
  if (analysisMigrated) log('added guaranteed-analysis columns to products');
  let analysisWritten = 0;
  const countBefore = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  const existing = new Set<string>(
    (db.prepare('SELECT gtin FROM products').all() as { gtin: string }[]).map((r) => r.gtin),
  );
  const existingBrands = new Set<string>(
    (db.prepare('SELECT DISTINCT lower(trim(brand)) b FROM products WHERE brand IS NOT NULL').all() as { b: string }[])
      .map((r) => r.b)
      .filter(Boolean),
  );

  const fresh = [...best.values()].filter(({ row }) => !existing.has(row.gtin));
  const alreadyHeld = best.size - fresh.length;

  // Tier C (5-9 ingredients) never ships, for the same reason the build excludes it: a score
  // read off a third of a label looks as confident as one read off all of it. Decide the
  // shippable set up front so --dry-run reports the number a real run would actually insert.
  const shippable = fresh.filter(({ row }) => row.tier !== 'C');
  const tierC = fresh.length - shippable.length;

  const bySource: Record<string, number> = {};
  const newBrandCounts: Record<string, number> = {};
  for (const { row, source } of shippable) {
    bySource[source] = (bySource[source] ?? 0) + 1;
    const b = row.brand.toLowerCase().trim();
    if (!existingBrands.has(b)) newBrandCounts[row.brand] = (newBrandCounts[row.brand] ?? 0) + 1;
  }

  const inserted = shippable.length;
  if (!opts.dryRun) {
    const insert = db.prepare(
      `INSERT OR IGNORE INTO products (gtin, name, brand, image_url, ingredients, species, category, tier)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    );
    db.exec('BEGIN');
    for (const { row } of shippable) {
      insert.run(
        row.gtin,
        row.name,
        row.brand,
        row.imageUrl,
        packIngredients(row.ingredients),
        row.species,
        row.category,
        row.tier,
      );
    }
    db.exec('COMMIT');

    /**
     * Macros are written for every harvested row that states them, not only the newly inserted
     * ones. Most of what a US sweep returns is a product the catalog already holds — the row is
     * skipped by INSERT OR IGNORE, and its guaranteed analysis would be thrown away with it,
     * even though that is the field the catalog is missing and the page has already been paid
     * for. Each column is filled only when it is still NULL, so a later, thinner source can
     * never overwrite a value an earlier one supplied.
     */
    const sets = ANALYSIS_COLUMNS.map(([, col]) => `${col} = COALESCE(${col}, ?)`).join(', ');
    const updateAnalysis = db.prepare(`UPDATE products SET ${sets} WHERE gtin = ?`);
    db.exec('BEGIN');
    for (const { row, analysis } of best.values()) {
      if (!analysis) continue;
      const values = ANALYSIS_COLUMNS.map(([field]) => analysis[field] ?? null);
      const r = updateAnalysis.run(...values, row.gtin);
      if (r.changes) analysisWritten++;
    }
    db.exec('COMMIT');
    const setMeta = db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)');
    setMeta.run('ingested_at', new Date().toISOString());
    if (inserted) {
      // `meta.version` is what the app reports for telemetry and display, and what matchkit
      // stamps into a baseline. Only `build` used to set it, so an ingested catalog kept
      // claiming the date of the vendor build it started from — two materially different
      // catalogs comparing as the same version, which is the one thing a version must not do.
      setMeta.run('version', new Date().toISOString().slice(0, 10).replace(/-/g, ''));
      // Keep `source` (the base vendor delivery) intact and record the retailers separately,
      // so provenance reads as "this build, plus these" rather than being overwritten.
      const prior = (db.prepare("SELECT value FROM meta WHERE key='ingest_sources'").get() as { value?: string } | undefined)
        ?.value;
      const merged = [...new Set([...(prior ? prior.split(',') : []), ...Object.keys(bySource)])].sort();
      setMeta.run('ingest_sources', merged.join(','));
    }
  }

  const countAfter = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  if (!opts.dryRun) {
    db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('count', String(countAfter));
  }

  // Search reads `product_groups`, not `products` (see group.ts). A freshly inserted row has a
  // null group_id and no group of its own, so until `group --apply` runs it resolves on a scan
  // but is invisible to search — a silent half-landing that looks like a successful ingest.
  // Report it rather than leave it to be noticed in the app.
  const grouped = (db.prepare("SELECT count(*) c FROM sqlite_master WHERE type='table' AND name='product_groups'").get() as {
    c: number;
  }).c > 0;
  const ungrouped = grouped
    ? (db.prepare('SELECT count(*) c FROM products WHERE group_id IS NULL').get() as { c: number }).c
    : 0;

  db.close();

  return {
    read,
    rejected,
    candidates: best.size,
    alreadyHeld,
    brandsFolded,
    tierC,
    inserted,
    analysisWritten,
    analysisMigrated,
    bySource,
    topNewBrands: Object.entries(newBrandCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20),
    countBefore,
    countAfter,
    grouped,
    ungrouped,
  };
}
