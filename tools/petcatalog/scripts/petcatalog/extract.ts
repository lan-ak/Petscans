/**
 * The filter cascade, validated against the real 78,325-record vendor delivery.
 *
 * Every rejection rule here exists because the delivered data contained rows that would
 * otherwise produce a wrong score or a barcode no scanner can emit. The counts each rule
 * removed on that file are recorded next to it; `petcatalog audit` reprints them so a
 * regression in the vendor feed is visible rather than silent.
 */

import { canonical, isShippable } from './gtin';

export interface CatalogRow {
  gtin: string;
  name: string;
  brand: string;
  imageUrl: string;
  ingredients: string;
  species: 'dog' | 'cat';
  category: 'food' | 'treat';
  nIngredients: number;
  tier: 'A' | 'B' | 'C' | 'S';
}

export type RejectReason =
  | 'bad_gtin'
  | 'not_retail_barcode'
  | 'junk_brand'
  | 'thin_ingredients'
  | 'word_split'
  | 'placeholder_ingredients'
  | 'empty_ingredients'
  | 'non_english'
  | 'vague_labelling'
  | 'unknown_species'
  | 'duplicate_gtin';

/** Marketplace resellers that publish under a placeholder brand. */
const JUNK_BRAND = /^(generic|importados|pet ?food|pet kare|urbanx|admc|fanzx|unbranded|unbranding|n\/?a)$/i;

/** Spanish-language listings. Their ingredient text is sometimes English, so check both. */
const SPANISH = /\b(para (perros|gatos)|comida|h[uú]meda|paquete|alimento|golosinas|sabor|carne|pollo|arroz|subproductos)\b/i;

/**
 * EU-style labelling. "Meat and animal derivatives" and friends are legal in the EU but
 * name no actual ingredient, so they score as noise — worse than having no data, because
 * the user sees a confident number derived from nothing.
 */
const VAGUE = /derivatives of vegetable origin|meat and animal derivatives|various sugars|derivatives of|oils and fats|cereals\b/i;

const CAT = /\bcat\b|kitten|feline/i;
const DOG = /\bdog\b|puppy|canine/i;
const TREAT = /treat|chew|biscuit|jerky|bone|rawhide|dental|snack|training/i;

/** 'cat' / 'dog' when the text names exactly one of them, null when it names both or neither. */
function decideSpecies(text: string): 'dog' | 'cat' | null {
  const isCat = CAT.test(text);
  const isDog = DOG.test(text);
  if (isCat === isDog) return null;
  return isCat ? 'cat' : 'dog';
}

/** `ingredients_full` arrives as JSON blocks: [{"type":"Ingredients","values":"..."}]. */
function ingredientBlocks(raw: unknown): string[] {
  if (raw === null || raw === undefined || raw === '' || raw === 'null' || raw === '[]') return [];
  let parsed: unknown = raw;
  if (typeof raw === 'string') {
    try {
      parsed = JSON.parse(raw);
    } catch {
      return [String(raw)];
    }
  }
  if (Array.isArray(parsed)) {
    return parsed
      .filter((b): b is { values: unknown } => typeof b === 'object' && b !== null && 'values' in b)
      .map((b) => String(b.values))
      .filter(Boolean);
  }
  return [String(parsed)];
}

/**
 * Marketing/analysis debris that the vendor scrape appended to ~4% of ingredient fields:
 * a leaked Guaranteed Analysis / nutrition table, HTML, marketing sentences, or contact
 * blurbs. Everything from the first of these markers onward is never an ingredient, so we
 * truncate there. Matched case-insensitively.
 */
// No leading \b: HTML stripping regularly welds the heading onto the last ingredient with no
// separator ("…Rosemary ExtractGuaranteed Analysis:"), and a leading word boundary cannot match
// there. These are distinctive multi-word phrases, so matching mid-word is safe and intended.
const TABLE_MARKER =
  /(guaranteed analysis|crude protein|crude fat|crude fib|metabolizable energy|calorie content|calorie information|feeding instructions?|feeding guidelines?|feeding directions?|storage instructions?|intended as a chew)\b/i;

/** A token that is marketing prose or a contact/URL blurb rather than an ingredient. */
const PROSE_TOKEN =
  /\b(we |our |your (dog|cat|pet)|this product|these treats?|made with|family owned|dedicated to|call \d|visit (our|us)|www\.|https?:\/\/|customer care|satisfaction|money back|guarantee)\b/i;

/**
 * Strip the parts of a scraped ingredient string that are not ingredients: HTML markup and
 * entities, then anything from a Guaranteed-Analysis / nutrition-table marker onward.
 */
function cleanIngredientText(raw: string): string {
  let s = raw
    .replace(/<[^>]*>/g, ' ') // HTML tags
    // HTML entities — the trailing ';' is optional because an earlier naive splitter
    // sometimes consumed it, leaving bare "&amp" fragments in already-stored data.
    .replace(/&(amp|lt|gt|quot|apos|nbsp|copy|reg|trade|#\d+);?/gi, ' ')
    .replace(/�/g, ' '); // replacement char from bad encoding
  const marker = s.search(TABLE_MARKER);
  if (marker >= 0) s = s.slice(0, marker);
  return s;
}

/**
 * Split on comma/semicolon only at parenthesis depth 0 — mirrors
 * IngredientMatcher.splitIngredientList so what we store is what the app parses. A naive
 * split shatters grouped sub-ingredients like "Vitamins (A Supplement, D3 Supplement)"
 * into dangling-paren fragments.
 */
function splitIngredients(text: string): string[] {
  const tokens: string[] = [];
  let current = '';
  let depth = 0;
  for (const ch of text) {
    if (ch === '(' || ch === '[' || ch === '{') {
      depth++;
      current += ch;
    } else if (ch === ')' || ch === ']' || ch === '}') {
      depth = Math.max(0, depth - 1);
      current += ch;
    } else if ((ch === ',' || ch === ';') && depth === 0) {
      tokens.push(current);
      current = '';
    } else {
      current += ch;
    }
  }
  tokens.push(current);
  return tokens.map((t) => t.trim()).filter(Boolean);
}

/**
 * The single ingredient tokenizer for every ingestion path (build cascade + enrich). Cleans
 * scrape debris, splits parenthesis-aware, and drops single-char punctuation and marketing
 * prose. Keeping this one function means what `enrich` writes is cleaned identically to what
 * `build` writes, and both match what IngredientMatcher parses on-device.
 */
export function tokenizeIngredients(rawText: string): string[] {
  return splitIngredients(cleanIngredientText(rawText)).filter((t) => t.length > 1 && !PROSE_TOKEN.test(t));
}

/**
 * Words that are never an ingredient on their own — they only ever appear inside one
 * ("preserved with mixed tocopherols", "chicken meal"). Seeing one standing alone as its own
 * token means the list was split on the wrong character.
 */
const FRAGMENT_WORD =
  /^(with|and|or|of|from|preserved|added|natural|dried|ground|whole|mixed|other|less|than|for|in|the|plus|source|contains|free|fresh|raw|pure|organic|meal|oil|extract|powder|flour|protein|starch|fiber|fibre)$/i;

/** Template text that reached production instead of real data. 87 such rows are already shipped. */
const PLACEHOLDER_TOKEN = /^ingredient\s*\d+$/i;

/**
 * Did the source split this list on spaces rather than commas?
 *
 * Ren's Pets serves ~57% of its ingredient strings word-shredded — "Wheat flour, glycerin,
 * wheat gluten" arrives as "Wheat, flour, glycerin, wheat, gluten," — and inconsistently, so
 * the same product in two sizes can be clean in one and shredded in the other. The token count
 * stays high, so a length threshold waves it straight through and the app ends up scoring
 * "Wheat" and "flour" as separate ingredients.
 *
 * A real list of any length carries multi-word ingredients ("chicken by-product meal",
 * "mixed tocopherols"). Requiring a lone fragment word as well spares the rare genuine
 * all-single-word list — a Temptations variety pack really is "Chicken, Salmon, Beef, Pork".
 * Measured against the 27,053 shipped rows: zero false positives.
 */
function looksWordSplit(tokens: string[]): boolean {
  if (tokens.length < 8) return false;
  const singleWord = tokens.filter((t) => !t.includes(' ')).length / tokens.length;
  return singleWord >= 0.9 && tokens.some((t) => FRAGMENT_WORD.test(t));
}

/** The failure modes that are provably corruption rather than merely thin data. */
export type CorruptionReason = 'placeholder_ingredients' | 'word_split' | 'empty_ingredients';

/**
 * Judge an already-stored ingredient string, so `clean` audits the shipped catalog with the
 * exact rules `extract` applies at the front door — one definition, no drift between them.
 */
export function auditIngredients(text: string): CorruptionReason | null {
  const tokens = tokenizeIngredients(text);
  // A stored row with nothing left to parse scores off an empty list — worse than absent,
  // because the product looks known. Six such rows predate this check.
  if (!tokens.length) return 'empty_ingredients';
  if (tokens.filter((t) => PLACEHOLDER_TOKEN.test(t)).length >= 3) return 'placeholder_ingredients';
  if (looksWordSplit(tokens)) return 'word_split';
  return null;
}

/**
 * A short list that is genuinely the whole label, not a truncated one.
 *
 * Single-ingredient treats are a real and popular category — bully sticks, freeze-dried
 * liver, sweet potato chews, chicken feet — and "Canadian Beef Lung" or "Sweet Potato" is the
 * complete, correct ingredient statement. Rejecting them means the user scans a bag we could
 * have scored and gets nothing.
 *
 * Complete foods are different: AAFCO complete-and-balanced requires a vitamin and mineral
 * package, so a *food* claiming two ingredients has been truncated. Hence treats only.
 *
 * The trailing comma is the tell for the shredded-source case ("Sweet,  Potato,"), which at
 * this length is otherwise indistinguishable from a real two-ingredient label.
 */
function isCompleteShortLabel(tokens: string[], rawText: string, category: 'food' | 'treat'): boolean {
  if (category !== 'treat') return false;
  if (tokens.length < 1 || tokens.length > 4) return false;
  if (rawText.trim().endsWith(',')) return false;
  return !tokens.some((t) => FRAGMENT_WORD.test(t));
}

/**
 * The vendor's own extractor left ingredients behind in other fields on ~7,280 rows.
 * Recovering them is free yield.
 */
function recoverIngredients(row: Record<string, unknown>): string {
  for (const field of ['ingredients', 'product_details', 'specifications', 'description', 'short_description']) {
    const v = row[field];
    if (!v) continue;
    const s = typeof v === 'string' ? v : JSON.stringify(v);
    const m = s.match(/ingredient[s]?\s*[:\-]\s*([\s\S]{40,3000})/i);
    if (m) return m[1];
  }
  return '';
}

export function extract(row: Record<string, unknown>): CatalogRow | RejectReason {
  const gtin = canonical((row.gtin as string) || (row.upc as string));
  if (!gtin) return 'bad_gtin';
  if (!isShippable(gtin)) return 'not_retail_barcode';

  const brand = String(row.brand ?? '').trim();
  if (!brand || JUNK_BRAND.test(brand)) return 'junk_brand';

  const rawText = ingredientBlocks(row.ingredients_full).join(' ') || recoverIngredients(row);

  // Tokenize the way IngredientMatcher does (parenthesis-aware) after stripping scrape debris,
  // so what we store is what it will parse.
  const tokens = tokenizeIngredients(rawText);

  // Corruption checks run before the length gate: a shredded list has a *high* token count, so
  // testing length first lets the worst data through as tier A.
  const corrupt = auditIngredients(rawText);
  if (corrupt) return corrupt;

  const name = String(row.product_name ?? '').trim();
  if (SPANISH.test(name) || SPANISH.test(rawText)) return 'non_english';
  if (VAGUE.test(rawText)) return 'vague_labelling';

  const blob = `${name} ${row.category_path ?? ''} ${row.breadcrumb_text ?? ''}`;
  const category: 'food' | 'treat' = TREAT.test(blob) ? 'treat' : 'food';

  // A 1-4 ingredient treat can be a complete label; a 1-4 ingredient food cannot.
  if (tokens.length < 5 && !isCompleteShortLabel(tokens, rawText, category)) return 'thin_ingredients';

  // Species drives which rules ScoreCalculator applies, so a wrong guess is a wrong score.
  // The product name is the most specific signal; fall back to the category path only when
  // the name is silent, and refuse to guess when both signals are ambiguous.
  const species = decideSpecies(name) ?? decideSpecies(blob);
  if (!species) return 'unknown_species';

  const imageUrl = String(row.main_image ?? '').trim();
  const nIngredients = tokens.length;

  return {
    gtin,
    name: name.slice(0, 120),
    brand: brand.slice(0, 60),
    imageUrl: imageUrl.slice(0, 300),
    ingredients: tokens.join(', '),
    species,
    category,
    nIngredients,
    // 'S' = short but complete (a single-ingredient chew). Distinct from 'C' so the two stay
    // separable in the DB: C is a list we suspect is truncated and never ship, S is a whole
    // label that happens to be one line. The app reads `tier` but does not branch on it.
    tier: isCompleteShortLabel(tokens, rawText, category)
      ? 'S'
      : nIngredients >= 20 && imageUrl
        ? 'A'
        : nIngredients >= 10
          ? 'B'
          : 'C',
  };
}
