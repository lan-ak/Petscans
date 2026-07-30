/**
 * Re-audit the shipped catalog against the corruption detectors.
 *
 * `extract` only guards the front door: rows written before a detector existed are already in
 * the file and stay there. This walks what is actually stored and removes the rows whose
 * ingredient text is provably not an ingredient list — the two failure modes worth deleting
 * for, because both produce a confident score computed from nothing:
 *
 *   placeholder_ingredients — literal template text ("ingredient1, ingredient2, …"). 87 such
 *                             rows were shipping before this existed.
 *   word_split              — a list split on spaces instead of commas, so "wheat flour"
 *                             scores as "wheat" plus "flour".
 *
 * Deliberately narrow. It does not re-run the whole cascade: rules like image presence or
 * species inference have shifted over time, and re-litigating them would delete rows that are
 * perfectly good. Only provable corruption is removed.
 */

import { DatabaseSync } from 'node:sqlite';
import { auditIngredients, tokenizeIngredients, type CorruptionReason } from './extract';
import { packIngredients, unpackIngredients } from './pack';

export interface CleanResult {
  scanned: number;
  /** Rows whose stored text still held debris a later rule strips; rewritten, not deleted. */
  repaired: number;
  /** Groups whose representative row was deleted — invisible to search until a regroup. */
  orphanedGroups: number;
  byReason: Record<string, number>;
  removed: number;
  samples: { gtin: string; brand: string; name: string; reason: string; ingredients: string }[];
  countBefore: number;
  countAfter: number;
}

export function cleanCatalog(opts: { dbPath: string; apply: boolean; onLog?: (s: string) => void }): CleanResult {
  const log = opts.onLog ?? (() => {});
  const db = new DatabaseSync(opts.dbPath);

  const codec = (db.prepare("SELECT value FROM meta WHERE key='ingredients_codec'").get() as { value?: string } | undefined)
    ?.value;
  const packed = codec === 'deflate-raw';

  const rows = db.prepare('SELECT gtin, brand, name, ingredients FROM products').all() as {
    gtin: string;
    brand: string;
    name: string;
    ingredients: Uint8Array | string;
  }[];

  const byReason: Record<string, number> = {};
  const doomed: string[] = [];
  const samples: CleanResult['samples'] = [];

  for (const r of rows) {
    const text = packed ? unpackIngredients(r.ingredients as Uint8Array) : String(r.ingredients);
    const reason: CorruptionReason | null = auditIngredients(text);
    if (!reason) continue;
    byReason[reason] = (byReason[reason] ?? 0) + 1;
    doomed.push(r.gtin);
    if (samples.length < 12) {
      samples.push({ gtin: r.gtin, brand: r.brand, name: r.name, reason, ingredients: text.slice(0, 90) });
    }
  }

  // Repair pass: re-run the current tokenizer over stored text. Rows written before a
  // debris rule existed keep that debris forever — 37 rows still carry a leaked "Feeding
  // Instructions:" block inside the ingredient list. Re-tokenising strips it. Only shrinking
  // rewrites are applied: a repair that *adds* tokens would mean the tokenizer got looser,
  // which is not something to apply blindly to shipped data.
  const doomedSet = new Set(doomed);
  const repairs: { gtin: string; text: string }[] = [];
  for (const r of rows) {
    if (doomedSet.has(r.gtin)) continue;
    const text = packed ? unpackIngredients(r.ingredients as Uint8Array) : String(r.ingredients);
    const retokenized = tokenizeIngredients(text).join(', ');
    if (retokenized && retokenized.length < text.length) repairs.push({ gtin: r.gtin, text: retokenized });
  }

  const countBefore = rows.length;
  let removed = 0;
  if (opts.apply && repairs.length) {
    const upd = db.prepare('UPDATE products SET ingredients = ? WHERE gtin = ?');
    db.exec('BEGIN');
    for (const rep of repairs) upd.run(packed ? packIngredients(rep.text) : rep.text, rep.gtin);
    db.exec('COMMIT');
    log(`repaired ${repairs.length} rows (re-tokenised, debris stripped)`);
  }
  if (opts.apply && doomed.length) {
    const del = db.prepare('DELETE FROM products WHERE gtin = ?');
    db.exec('BEGIN');
    for (const g of doomed) {
      del.run(g);
      removed++;
    }
    db.exec('COMMIT');
    db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('cleaned_at', new Date().toISOString());
    log(`deleted ${removed} corrupt rows`);
  }

  const countAfter = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  if (opts.apply) {
    db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('count', String(countAfter));
  }

  // Search joins product_groups to products on the representative gtin, and it is an INNER
  // join — so deleting a row that happens to represent a group takes the whole group with it,
  // every sibling size included, silently. Count the orphans rather than let search shrink
  // without saying why; `group --apply` recomputes and repairs them.
  const grouped = (db.prepare("SELECT count(*) c FROM sqlite_master WHERE type='table' AND name='product_groups'").get() as {
    c: number;
  }).c > 0;
  const orphanedGroups = grouped
    ? (db
        .prepare('SELECT count(*) c FROM product_groups g LEFT JOIN products p ON p.gtin = g.gtin WHERE p.gtin IS NULL')
        .get() as { c: number }).c
    : 0;

  db.close();

  return { orphanedGroups, scanned: rows.length, repaired: opts.apply ? repairs.length : repairs.length, byReason, removed, samples, countBefore, countAfter };
}
