/**
 * Size-variant consolidation for the shipped catalog.
 *
 * The vendor lists every pack size as its own SKU — "…Chicken & Pea Recipe Dry Dog Food,
 * 4 lb / 11 lb / 24 lb", plus "(Pack of 4)" multipacks and the same product re-listed by
 * several retailers under different GTINs. Search shows all of them, so one recipe can eat
 * a whole screen of results. This stage folds those into one listing.
 *
 * Nothing is deleted: the scan path is `product(gtin:)` and every barcode has to keep
 * resolving. Instead each row gets a `group_id`, and `product_groups` names one
 * representative row per group. Search reads `product_groups`; scan reads `products`.
 *
 * The grouping key is brand + species + category + exact ingredient blob + the product name
 * with size/pack tokens stripped. The ingredient blob alone is far too loose — it collapses
 * all 205 breed-specific "Healthy Breeds …" SKUs into one listing, which are different
 * products that happen to share a recipe.
 *
 * Idempotent: recomputes from scratch every run. Run it AFTER `pack` — pack rebuilds the
 * products table and drops `group_id` with it.
 */

import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';

/** Units that can carry a pack size in a product name. */
const UNIT =
  '(?:oz|ounce|ounces|lb|lbs|pound|pounds|g|gram|grams|kg|ml|l|liter|litre|ct|count|pk|pack|packs|' +
  'case|cases|can|cans|pouch|pouches|bag|bags|box|boxes|tray|trays|stick|sticks|piece|pieces|tub|tubs|' +
  'jar|jars|roll|rolls|bar|bars|treat|treats|serving|servings|tablet|tablets|chew|chews|cup|cups|' +
  // `in` only counts as inches when a number does not follow it, so the "3 in 1" / "4-in-1"
  // formula names (and the 8-in-1 brand) keep their digits instead of being read as a size.
  'pt|qt|gal|inch|in(?![\\s-]*\\d)|cm|mm)';

/**
 * Everything that expresses "how much of it", in the order it has to be stripped —
 * parenthesised forms first, so "(Pack of 4)" goes before the bare-number rules can
 * chew a hole in the middle of it.
 */
const SIZE_PATTERNS: RegExp[] = [
  /\(\s*(?:pack|case|box|value pack|multi-?pack)\s+of\s+\d+[^)]*\)/gi,
  new RegExp(`\\(\\s*\\d+\\s*[-x ]?\\s*${UNIT}[^)]*\\)`, 'gi'),
  /\(\s*\d+\s*(?:pack|pk|count|ct)\s*\)/gi,
  /\b\d+\s*(?:pack|pk)\b/gi,
  /\bpack of\s*\d+\b/gi,
  /\bcase of\s*\d+\b/gi,
  /\bbox of\s*\d+\b/gi,
  // The range form ("12-16 oz"). The lookbehind keeps it from starting halfway through a
  // decimal: without it "2.47-oz" matches as "47-oz" and strands a "2" in the key, which
  // splits groups that should merge.
  new RegExp(`(?<![\\d.])\\d+\\s*[-x]\\s*\\d*\\.?\\d*\\s*${UNIT}\\b`, 'gi'),
  new RegExp(`\\b\\d*\\.?\\d+\\s*-?\\s*${UNIT}\\b\\.?`, 'gi'),
  new RegExp(`\\b\\d+\\s*/\\s*\\d*\\.?\\d+\\s*${UNIT}\\b`, 'gi'),
  /\bsize\s*[:#]?\s*\d+\b/gi,
];

/**
 * Bare size adjectives. Safe to drop only because the ingredient blob is part of the key:
 * "Small Dental Chews" and "Large Dental Chews" merge only when the recipe is byte
 * identical, which is exactly the size-variant case we want folded.
 */
const SIZE_WORDS = /\b(?:small|medium|large|x-?large|xl|xs|mini|tiny|giant|jumbo|bulk|value|variety|multi)\b/gi;

/**
 * The fold that makes typed text and stored text comparable. Both `search_text` and the
 * user's query go through it, so it decides what search will and won't forgive:
 *
 *   - apostrophes vanish, because nobody types "hill's" — they type "hills"
 *   - accents are stripped, so "puree" finds "Purée"
 *   - every other punctuation run becomes a space, so "grain-free" and "grain free" agree
 *
 * `LocalCatalogStore.foldForSearch` is the Swift half and has to stay identical: the query
 * is folded on device, the text it matches was folded here, and any drift between the two
 * shows up as products that simply cannot be found.
 */
export function foldForSearch(s: string): string {
  return stripAccents(s)
    .replace(/['’`]+/gu, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

/** Case and accents only — punctuation survives, which the size patterns depend on. */
function stripAccents(s: string): string {
  return s.normalize('NFD').replace(/\p{M}+/gu, '').toLowerCase();
}

/** Product name → the recipe identity inside it, with every size/pack token removed. */
export function normalizeName(name: string): string {
  // Accents go first but punctuation stays: the size patterns read parentheses and decimal
  // points, so folding "3.15 lb" to "3 15 lb" up here would leave a stray "3" behind and
  // split a group that should merge.
  let s = stripAccents(name);
  for (const re of SIZE_PATTERNS) s = s.replace(re, ' ');
  s = s.replace(SIZE_WORDS, ' ');
  return foldForSearch(s);
}

/** Data-completeness tier, best first — decides which variant represents the group. */
const TIER_RANK: Record<string, number> = { S: 0, A: 1, B: 2, C: 3 };

interface Row {
  gtin: string;
  name: string;
  brand: string | null;
  image_url: string | null;
  ingredients: Uint8Array;
  species: string;
  category: string;
  tier: string;
}

export interface GroupResult {
  rows: number;
  groups: number;
  multiVariant: number;
  absorbed: number;
  largest: number;
  exactDuplicates: number;
  searchTextBytes: number;
  samples: { name: string; variants: string[] }[];
}

/**
 * The variant that stands in for the group in search results. Prefers the row a user is most
 * likely to recognise and the app is most able to render: an image, the most trustworthy
 * tier, then the shortest name — the base "…, 24 lb." beats "…, 24 lb. Bag (Pack of 48)".
 * GTIN breaks ties so the choice is stable across rebuilds.
 */
function pickRepresentative(variants: Row[]): Row {
  return [...variants].sort((a, b) => {
    // Ingredients are deliberately not a tiebreak: they are part of the grouping key, so every
    // variant in the group carries the byte-identical blob and the comparison never fires.
    const img = Number(!a.image_url) - Number(!b.image_url);
    if (img) return img;
    const tier = (TIER_RANK[a.tier] ?? 9) - (TIER_RANK[b.tier] ?? 9);
    if (tier) return tier;
    const len = a.name.length - b.name.length;
    if (len) return len;
    return a.gtin < b.gtin ? -1 : 1;
  })[0];
}

/**
 * Rows that grouping has not seen yet, or null if this catalog has no grouping at all.
 *
 * Worth checking after anything that inserts: search reads `product_groups`, so a freshly
 * ingested row with no group is invisible to search even though a scan resolves it fine. That
 * failure is silent, which is exactly why every insert path shouts about it.
 */
export function ungroupedCount(dbPath: string): number | null {
  const db = new DatabaseSync(dbPath);
  try {
    const grouped = db
      .prepare("SELECT count(*) c FROM sqlite_master WHERE type='table' AND name='product_groups'")
      .get() as { c: number };
    if (!grouped.c) return null;
    return (db.prepare('SELECT count(*) c FROM products WHERE group_id IS NULL').get() as { c: number }).c;
  } finally {
    db.close();
  }
}

/**
 * Compute groups and write `product_groups` + `products.group_id` into an existing catalog.
 * `apply: false` measures without touching the database.
 */
export function groupCatalog(opts: {
  dbPath: string;
  apply: boolean;
  onLog?: (s: string) => void;
}): GroupResult {
  const onLog = opts.onLog ?? (() => {});
  const db = new DatabaseSync(opts.dbPath);

  const rows = db
    .prepare('SELECT gtin, name, brand, image_url, ingredients, species, category, tier FROM products')
    .all() as unknown as Row[];
  onLog(`read ${rows.length} rows`);

  const buckets = new Map<string, Row[]>();
  for (const r of rows) {
    const recipe = createHash('sha1').update(r.ingredients).digest('base64');
    const key = [r.brand ?? '', r.species, r.category, recipe, normalizeName(r.name)].join('\0');
    const bucket = buckets.get(key);
    if (bucket) bucket.push(r);
    else buckets.set(key, [r]);
  }

  let multiVariant = 0;
  let largest = 0;
  let exactDuplicates = 0;
  let searchTextBytes = 0;
  const samples: GroupResult['samples'] = [];
  const groups: { gtin: string; variantCount: number; searchText: string; members: string[] }[] = [];

  for (const variants of buckets.values()) {
    const rep = pickRepresentative(variants);
    // Everything search matches against, denormalised onto the group so the LIKE scan never
    // has to touch `products`. That is the whole performance story: with the filter on the
    // products table, SQLite joins all 25k rows before it can test one — measured 13.5 ms a
    // query. Filtering here and joining only the survivors is 4.2 ms, faster than the flat
    // ungrouped search it replaces. Sibling names are folded in so a user who types "24 lb"
    // still finds the listing when the 4 lb row is the one on display.
    const names = [...new Set([rep.name, ...variants.map((v) => v.name)])];
    const searchText = foldForSearch([...names, rep.brand ?? ''].join(' '));
    searchTextBytes += Buffer.byteLength(searchText);
    groups.push({
      gtin: rep.gtin,
      variantCount: variants.length,
      searchText,
      members: variants.map((v) => v.gtin),
    });

    if (variants.length > 1) {
      multiVariant++;
      largest = Math.max(largest, variants.length);
      if (new Set(variants.map((v) => v.name)).size === 1) exactDuplicates++;
      if (samples.length < 8 && variants.length < 6) {
        samples.push({ name: rep.name, variants: variants.map((v) => v.name) });
      }
    }
  }

  const result: GroupResult = {
    rows: rows.length,
    groups: groups.length,
    multiVariant,
    absorbed: rows.length - groups.length,
    largest,
    exactDuplicates,
    searchTextBytes,
    samples,
  };

  if (!opts.apply) {
    db.close();
    return result;
  }

  db.exec('BEGIN');
  db.exec('DROP TABLE IF EXISTS product_groups');
  // An earlier build of this stage shipped these; dropping the table takes its own index with
  // it, but products' does not go on its own.
  db.exec('DROP INDEX IF EXISTS idx_products_group');
  db.exec(`CREATE TABLE product_groups (
    group_id      INTEGER PRIMARY KEY,
    gtin          TEXT NOT NULL,      -- representative variant; join products on this
    variant_count INTEGER NOT NULL,
    search_text   TEXT NOT NULL       -- lowercased rep name + every sibling name + brand
  )`);

  // group_id may already exist from a previous run; node:sqlite has no ADD COLUMN IF NOT EXISTS.
  const hasGroupId = (db.prepare('PRAGMA table_info(products)').all() as { name: string }[])
    .some((c) => c.name === 'group_id');
  if (!hasGroupId) db.exec('ALTER TABLE products ADD COLUMN group_id INTEGER');

  const insGroup = db.prepare(
    'INSERT INTO product_groups (group_id, gtin, variant_count, search_text) VALUES (?, ?, ?, ?)',
  );
  const setGroup = db.prepare('UPDATE products SET group_id = ? WHERE gtin = ?');
  let groupId = 0;
  for (const g of groups) {
    groupId++;
    insGroup.run(groupId, g.gtin, g.variantCount, g.searchText);
    for (const gtin of g.members) setGroup.run(groupId, gtin);
  }

  // No index on product_groups.gtin or products.group_id on purpose: search drives from
  // product_groups and probes products through its own gtin index, so neither is ever used —
  // together they cost 0.9 MB of a file that ships inside the app. Uniqueness is asserted
  // below instead. Add `products (group_id)` back the day something reads a group's siblings
  // ("also available in 4 lb"), or that lookup becomes a scan of a 20 MB table.
  db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('grouped_at', new Date().toISOString());
  db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('group_count', String(groups.length));

  // The invariants search depends on, checked before the commit so a breach rolls the catalog
  // back instead of shipping it. A silent breach would surface as products missing from
  // search — an error here is much cheaper to notice.
  const count = (sql: string): number => (db.prepare(sql).get() as { c: number }).c;
  const checks: [string, string][] = [
    ['rows left without a group_id', 'SELECT count(*) c FROM products WHERE group_id IS NULL'],
    ['rows representing more than one group', 'SELECT count(*) c FROM (SELECT gtin FROM product_groups GROUP BY gtin HAVING count(*) > 1)'],
    ['groups pointing at a gtin not in products', 'SELECT count(*) c FROM product_groups g LEFT JOIN products p ON p.gtin = g.gtin WHERE p.gtin IS NULL'],
  ];
  for (const [what, sql] of checks) {
    const n = count(sql);
    if (n) {
      db.exec('ROLLBACK');
      db.close();
      throw new Error(`grouping aborted: ${n} ${what}`);
    }
  }
  db.exec('COMMIT');

  // Stamping group_id rewrites every row of a table whose pages are mostly ingredient blob,
  // which leaves the file badly fragmented — ~0.5 MB of the growth is pure slack without this.
  db.exec('VACUUM');
  db.close();
  onLog(`wrote ${groups.length} groups over ${rows.length} rows`);
  return result;
}
