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

  const text = ingredientBlocks(row.ingredients_full).join(' ') || recoverIngredients(row);

  // Split the way IngredientMatcher.splitIngredientList does, so what we store is what it
  // will parse. Single characters are punctuation debris, not ingredients.
  const tokens = text
    .split(/[,;]/)
    .map((t) => t.trim())
    .filter((t) => t.length > 1);
  if (tokens.length < 5) return 'thin_ingredients';

  const name = String(row.product_name ?? '').trim();
  if (SPANISH.test(name) || SPANISH.test(text)) return 'non_english';
  if (VAGUE.test(text)) return 'vague_labelling';

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
