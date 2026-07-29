/**
 * Streams the vendor delivery through the filter cascade and writes the SQLite catalog
 * that ships inside the app bundle.
 *
 * Tier C (5-9 ingredients) is extracted but NOT written by default: those lists are
 * usually truncated, and a score computed from a third of a label reads as confident when
 * it isn't. Pass --include-tier-c to keep them.
 */

import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, rmSync, statSync } from 'node:fs';
import { dirname } from 'node:path';
import { streamJsonArray } from './stream';
import { extract, type CatalogRow, type RejectReason } from './extract';
import { packIngredients, INGREDIENTS_CODEC } from './pack';

export interface BuildOptions {
  source: string;
  out: string;
  includeTierC: boolean;
  onProgress?: (seen: number) => void;
}

export interface BuildResult {
  seen: number;
  rejected: Record<RejectReason, number>;
  written: number;
  byTier: Record<string, number>;
  bySpecies: Record<string, number>;
  byCategory: Record<string, number>;
  withImage: number;
  topBrands: [string, number][];
  bytes: number;
}

// A plain rowid table with a UNIQUE index on gtin, deliberately NOT `WITHOUT ROWID`:
// that variant stores the whole row (including the ~765-byte ingredient text) inside the
// primary-key B-tree, which doubled the file to 22 MB. The index gives the same O(log n)
// point lookup at half the size.
const SCHEMA = `
CREATE TABLE products (
  gtin          TEXT NOT NULL,
  name          TEXT NOT NULL,
  brand         TEXT,
  image_url     TEXT,
  ingredients   BLOB NOT NULL,   -- raw-DEFLATE of the ingredient text; see pack.ts / meta.ingredients_codec
  species       TEXT NOT NULL,
  category      TEXT NOT NULL,
  tier          TEXT NOT NULL
);
CREATE UNIQUE INDEX idx_products_gtin ON products (gtin);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
`;

export async function build(opts: BuildOptions): Promise<BuildResult> {
  const rejected = {
    bad_gtin: 0,
    not_retail_barcode: 0,
    junk_brand: 0,
    thin_ingredients: 0,
    non_english: 0,
    vague_labelling: 0,
    unknown_species: 0,
    duplicate_gtin: 0,
  } as Record<RejectReason, number>;

  // Dedupe in memory keyed by GTIN, keeping the deepest ingredient list. The vendor ships
  // the same product from several marketplace sellers at differing completeness.
  const best = new Map<string, CatalogRow>();
  let seen = 0;

  for await (const row of streamJsonArray<Record<string, unknown>>(opts.source)) {
    seen++;
    if (opts.onProgress && seen % 10_000 === 0) opts.onProgress(seen);

    const result = extract(row);
    if (typeof result === 'string') {
      rejected[result]++;
      continue;
    }
    const existing = best.get(result.gtin);
    if (existing) {
      rejected.duplicate_gtin++;
      if (result.nIngredients <= existing.nIngredients) continue;
    }
    best.set(result.gtin, result);
  }

  const rows = [...best.values()].filter((r) => opts.includeTierC || r.tier !== 'C');

  mkdirSync(dirname(opts.out), { recursive: true });
  rmSync(opts.out, { force: true });
  const db = new DatabaseSync(opts.out);
  db.exec('PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;');
  db.exec(SCHEMA);

  const insert = db.prepare(
    `INSERT INTO products (gtin, name, brand, image_url, ingredients, species, category, tier)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  db.exec('BEGIN');
  for (const r of rows) {
    // ingredients ship compressed; n_ingredients is dropped (derivable, never read on-device).
    insert.run(r.gtin, r.name, r.brand, r.imageUrl, packIngredients(r.ingredients), r.species, r.category, r.tier);
  }
  db.exec('COMMIT');

  const meta = db.prepare('INSERT INTO meta (key, value) VALUES (?, ?)');
  meta.run('version', new Date().toISOString().slice(0, 10).replace(/-/g, ''));
  meta.run('built_at', new Date().toISOString());
  meta.run('count', String(rows.length));
  meta.run('source', opts.source.split('/').pop() ?? opts.source);
  meta.run('ingredients_codec', INGREDIENTS_CODEC);

  db.exec('VACUUM');
  db.close();

  const tally = (pick: (r: CatalogRow) => string) =>
    rows.reduce<Record<string, number>>((acc, r) => ((acc[pick(r)] = (acc[pick(r)] ?? 0) + 1), acc), {});

  const brandCounts = tally((r) => r.brand);

  return {
    seen,
    rejected,
    written: rows.length,
    byTier: tally((r) => r.tier),
    bySpecies: tally((r) => r.species),
    byCategory: tally((r) => r.category),
    withImage: rows.filter((r) => r.imageUrl).length,
    topBrands: Object.entries(brandCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 12),
    bytes: statSync(opts.out).size,
  };
}
