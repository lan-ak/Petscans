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
  tier: 'A' | 'B' | 'C';
}

export type RejectReason =
  | 'bad_gtin'
  | 'not_retail_barcode'
  | 'junk_brand'
  | 'thin_ingredients'
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
const TABLE_MARKER =
  /\b(guaranteed analysis|crude protein|crude fat|crude fib|metabolizable energy|calorie content|calorie information)\b/i;

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
  if (tokens.length < 5) return 'thin_ingredients';

  const name = String(row.product_name ?? '').trim();
  if (SPANISH.test(name) || SPANISH.test(rawText)) return 'non_english';
  if (VAGUE.test(rawText)) return 'vague_labelling';

  const blob = `${name} ${row.category_path ?? ''} ${row.breadcrumb_text ?? ''}`;

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
    category: TREAT.test(blob) ? 'treat' : 'food',
    nIngredients,
    tier: nIngredients >= 20 && imageUrl ? 'A' : nIngredients >= 10 ? 'B' : 'C',
  };
}
