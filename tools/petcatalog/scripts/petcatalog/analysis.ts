/**
 * Guaranteed analysis / analytical constituents → numeric catalog columns.
 *
 * The catalog has only ever stored an ingredient list, and that is why nothing it scores ever
 * comes out badly: 22,095 of 31,142 products are tier A and no product has ever rated "Good".
 * An ingredient list says what is in the food, never how much, so two foods with the same
 * words in a different order are indistinguishable to the scorer. Macros are the axis it has
 * been missing.
 *
 * Two label formats arrive, and they are not the same statement:
 *
 *   UK/EU  an object of analytical constituents — {"Protein":"30%","Crude Oils and Fats":"17%"}
 *   US     one AAFCO string — "Crude Protein (Min.) 24 %, Crude Fat (Min.) 14 %, ..."
 *
 * Both are parsed to the same five percentages plus energy. Values are stored **as fed**,
 * exactly as the label states them, and deliberately not converted to a dry-matter basis here.
 * As-fed protein is not comparable across forms — a 10%-moisture kibble and an 80%-moisture
 * pâté with identical dry-matter protein differ by a factor of four on the label — so the
 * conversion matters, but it belongs to whoever is comparing, next to their own decision about
 * what to do when moisture is missing. Storing a derived number would bake that choice into
 * the shipped artifact and hide it. `moisture_pct` is stored precisely so it can be undone:
 * dry-matter % = as-fed % / (100 - moisture) * 100.
 */

import type { DatabaseSync } from 'node:sqlite';

export interface Analysis {
  protein?: number;
  fat?: number;
  fibre?: number;
  moisture?: number;
  ash?: number;
  kcalPerKg?: number;
}

/** Catalog column for each field. Order is the column order used by ingest and backfill. */
export const ANALYSIS_COLUMNS: [keyof Analysis, string][] = [
  ['protein', 'protein_pct'],
  ['fat', 'fat_pct'],
  ['fibre', 'fibre_pct'],
  ['moisture', 'moisture_pct'],
  ['ash', 'ash_pct'],
  ['kcalPerKg', 'kcal_per_kg'],
];

/** A percentage that could plausibly be on a pet food label. */
function pct(raw: string | undefined): number | undefined {
  if (!raw) return undefined;
  const m = String(raw).match(/(\d+(?:\.\d+)?)/);
  if (!m) return undefined;
  const n = Number(m[1]);
  return Number.isFinite(n) && n >= 0 && n <= 100 ? n : undefined;
}

/**
 * Key matchers for the UK object form, most specific first — "Crude Oils and Fats" has to be
 * tested before a bare /fat/, and `ash` is anchored so it cannot match "Potash".
 */
const UK_KEYS: [keyof Analysis, RegExp][] = [
  ['protein', /protein/i],
  ['fat', /oils?\s*(and|&)\s*fats?|crude\s*fats?|\bfats?\b/i],
  ['fibre', /fib(re|er)/i],
  ['moisture', /moisture/i],
  ['ash', /\bash\b/i],
];

/** US AAFCO string. Values carry commas ("8,000 IU/kg"), so this reads fields, never splits. */
export function parseUS(text: string): Analysis {
  const a: Analysis = {};
  const grab = (re: RegExp): number | undefined => pct(text.match(re)?.[1]);

  a.protein = grab(/crude\s*protein[^\d%]{0,24}(\d+(?:\.\d+)?)\s*%/i);
  a.fat = grab(/crude\s*fat[^\d%]{0,24}(\d+(?:\.\d+)?)\s*%/i);
  a.fibre = grab(/crude\s*fib(?:er|re)[^\d%]{0,24}(\d+(?:\.\d+)?)\s*%/i);
  a.moisture = grab(/moisture[^\d%]{0,24}(\d+(?:\.\d+)?)\s*%/i);
  a.ash = grab(/\bash\b[^\d%]{0,24}(\d+(?:\.\d+)?)\s*%/i);

  // "Calorie Content (Calculated): 1066 Kcal/Kg" — the per-can figure alongside it is a
  // different quantity, so the unit has to be matched, not just the number.
  const kcal = text.match(/([\d,]+(?:\.\d+)?)\s*kcal\s*\/\s*kg/i)?.[1];
  if (kcal) {
    const n = Number(kcal.replace(/,/g, ''));
    if (Number.isFinite(n) && n >= 100 && n <= 10_000) a.kcalPerKg = n;
  }
  return a;
}

function parseUK(obj: Record<string, string>): Analysis {
  const a: Analysis = {};
  for (const [field, re] of UK_KEYS) {
    if (a[field] !== undefined) continue;
    // Variety packs repeat the constituents per flavour ("Protein Turkey", "Moisture Turkey"),
    // so the first matching key wins rather than trying to reconcile several recipes.
    const hit = Object.keys(obj).find((k) => re.test(k));
    if (hit) a[field] = pct(obj[hit]);
  }
  const kcal = Object.entries(obj).find(([k]) => /kcal|energy|calorie/i.test(k))?.[1];
  if (kcal) {
    const n = Number(String(kcal).replace(/,/g, '').match(/(\d+(?:\.\d+)?)/)?.[1]);
    if (Number.isFinite(n) && n >= 100 && n <= 10_000) a.kcalPerKg = n;
  }
  return a;
}

/** Null when nothing usable was stated — an all-empty row is not worth a write. */
export function parseAnalysis(raw: Record<string, string> | undefined): Analysis | null {
  if (!raw) return null;
  const us = raw.guaranteedAnalysis;
  const a = us ? parseUS(us) : parseUK(raw);
  const kept = Object.fromEntries(Object.entries(a).filter(([, v]) => v !== undefined)) as Analysis;
  return Object.keys(kept).length ? kept : null;
}

/**
 * Read macros out of arbitrary page text.
 *
 * The AAFCO wording is regular enough ("Crude Protein (Min.) 24 %") to find in a plain markdown
 * scrape, which is why the backfill costs one credit a page instead of the five an extraction
 * schema would. A page that merely mentions protein in prose yields nothing, because the parser
 * requires the "crude" form and a percent sign.
 */
export function parseAnalysisText(text: string): Analysis | null {
  const a = parseUS(text);
  const kept = Object.fromEntries(Object.entries(a).filter(([, v]) => v !== undefined)) as Analysis;
  // One lone number off a long page is far more likely to be a coincidence than a label.
  return Object.keys(kept).length >= 2 ? kept : null;
}

/**
 * Add the analysis columns if they are absent. SQLite has no ADD COLUMN IF NOT EXISTS, and
 * this runs on every ingest, so it checks the table first and is a no-op thereafter.
 */
export function ensureAnalysisColumns(db: DatabaseSync): boolean {
  const have = new Set(
    (db.prepare('PRAGMA table_info(products)').all() as { name: string }[]).map((r) => r.name),
  );
  const missing = ANALYSIS_COLUMNS.filter(([, col]) => !have.has(col));
  for (const [, col] of missing) db.exec(`ALTER TABLE products ADD COLUMN ${col} REAL`);
  return missing.length > 0;
}
