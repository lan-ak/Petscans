/**
 * Ingredient compression for the shipped catalog.
 *
 * `ingredients` is 61% of catalog.sqlite (~18 MB of ~30). Stored as a per-row raw-DEFLATE
 * blob it roughly halves — and raw DEFLATE decodes natively on iOS via Apple's Compression
 * framework (`COMPRESSION_ZLIB` == raw DEFLATE), so the app needs no third-party codec.
 * Verified round-trip: Node `deflateRawSync` ↔ `compression_decode_buffer(..., COMPRESSION_ZLIB)`.
 *
 * The canonical catalog.sqlite is itself the shipped artifact, so build + enrich write the
 * compressed form and `pack` migrates an existing text catalog in place. Decompression only
 * ever happens on-device; the growth tools never read ingredients back, so nothing here
 * needs to inflate at runtime.
 */

import { DatabaseSync } from 'node:sqlite';
import { deflateRawSync, inflateRawSync } from 'node:zlib';

export const INGREDIENTS_CODEC = 'deflate-raw';

/** Text → raw-DEFLATE blob for the `ingredients` column. */
export function packIngredients(text: string): Uint8Array {
  return deflateRawSync(Buffer.from(text, 'utf8'), { level: 9 });
}

/** Inverse of packIngredients — used only for build-time verification, never on-device. */
export function unpackIngredients(blob: Uint8Array): string {
  return inflateRawSync(blob).toString('utf8');
}

export interface PackResult {
  migrated: boolean;
  rows: number;
  before: number;
  after: number;
  mismatches: number;
}

/**
 * Migrate a text-ingredients catalog to the compressed form in place: rewrite `ingredients`
 * as raw-DEFLATE blobs, drop the unused `n_ingredients` column, VACUUM. Idempotent — a DB
 * already stamped with the codec is left untouched. Every row is round-trip verified before
 * the swap; any mismatch aborts without touching the original table.
 */
export function packInPlace(dbPath: string, onLog: (s: string) => void = () => {}): PackResult {
  const db = new DatabaseSync(dbPath);
  const codec = (db.prepare("SELECT value FROM meta WHERE key='ingredients_codec'").get() as { value?: string } | undefined)?.value;
  const before = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  if (codec === INGREDIENTS_CODEC) {
    db.close();
    return { migrated: false, rows: before, before, after: before, mismatches: 0 };
  }

  /**
   * The rebuild below names its columns, so anything added to `products` after this file was
   * written (the guaranteed-analysis columns) would be silently dropped by a migration. This
   * path only ever runs on a catalog that has not been packed yet, and `build` does not create
   * those columns — but the failure would be a silent data loss on a shipped artifact, so it
   * refuses rather than guesses.
   */
  const cols = new Set((db.prepare('PRAGMA table_info(products)').all() as { name: string }[]).map((r) => r.name));
  const KNOWN = ['gtin', 'name', 'brand', 'image_url', 'ingredients', 'species', 'category', 'tier', 'group_id', 'n_ingredients'];
  const unknown = [...cols].filter((c) => !KNOWN.includes(c));
  if (unknown.length) {
    db.close();
    throw new Error(`pack would drop columns it does not know about: ${unknown.join(', ')} — update pack.ts before packing this catalog`);
  }

  db.exec('PRAGMA foreign_keys=OFF; BEGIN');
  db.exec(`CREATE TABLE products_packed (
    gtin TEXT NOT NULL, name TEXT NOT NULL, brand TEXT, image_url TEXT,
    ingredients BLOB NOT NULL, species TEXT NOT NULL, category TEXT NOT NULL, tier TEXT NOT NULL);`);
  const ins = db.prepare(
    `INSERT INTO products_packed (gtin, name, brand, image_url, ingredients, species, category, tier)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const rows = db.prepare('SELECT gtin, name, brand, image_url, ingredients, species, category, tier FROM products').all() as Record<string, unknown>[];
  let mismatches = 0;
  for (const r of rows) {
    const text = String(r.ingredients);
    const blob = packIngredients(text);
    if (unpackIngredients(blob) !== text) {
      mismatches++;
      continue;
    }
    ins.run(r.gtin as string, r.name as string, (r.brand ?? null) as string, (r.image_url ?? null) as string, blob, r.species as string, r.category as string, r.tier as string);
  }
  if (mismatches) {
    db.exec('ROLLBACK');
    db.close();
    throw new Error(`pack aborted: ${mismatches} rows failed round-trip verification`);
  }
  db.exec('DROP TABLE products');
  db.exec('ALTER TABLE products_packed RENAME TO products');
  db.exec('CREATE UNIQUE INDEX idx_products_gtin ON products (gtin)');
  db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('ingredients_codec', INGREDIENTS_CODEC);
  db.exec('COMMIT');
  db.exec('VACUUM');
  const after = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  db.close();
  onLog(`packed ${after} rows, dropped n_ingredients, ${mismatches} mismatches`);
  return { migrated: true, rows: after, before, after, mismatches };
}
