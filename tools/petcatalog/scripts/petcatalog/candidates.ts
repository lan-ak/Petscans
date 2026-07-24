/**
 * Candidate builders for enrichment. Both read the real source files on disk, so GTINs
 * are exact (never transcribed).
 *
 *  - chewyCandidates: the reviewed Chewy scrape. Has GTIN + identity but no ingredients;
 *    carries a PDP `url` we can scrape directly.
 *  - walmartCandidates: the Bright Data pull's identity-only rows (valid GTIN + brand +
 *    name, <5 ingredients). No usable `url` for ingredients (Walmart PDPs omit them), so
 *    these enrich via search→scrape — `url` is left undefined.
 */

import { readFileSync } from 'node:fs';
import { streamJsonArray } from './stream';
import type { Candidate } from './enrich';

const CAT = /\bcat\b|kitten|feline/i;
const DOG = /\bdog\b|puppy|canine/i;
const TREAT = /treat|chew|biscuit|jerky|bone|rawhide|dental|snack|training|topper/i;
const JUNK_BRAND = /^(generic|importados|pet ?food|pet kare|urbanx|admc|fanzx|unbranded|unbranding|n\/?a|nobrand)$/i;

function speciesOf(text: string): 'dog' | 'cat' | null {
  const c = CAT.test(text);
  const d = DOG.test(text);
  if (c === d) return null;
  return c ? 'cat' : 'dog';
}

/** Chewy scrape → one candidate per unique GTIN, keeping its PDP url. */
export function chewyCandidates(path: string): Candidate[] {
  const rows = JSON.parse(readFileSync(path, 'utf8')) as Record<string, unknown>[];
  const out = new Map<string, Candidate>();
  for (const r of rows) {
    const gtin = String(r.gtin ?? '').trim();
    if (!gtin) continue;
    const tree = Array.isArray(r.category_tree) ? (r.category_tree as { name?: string }[]).map((t) => t.name ?? '').join(' ') : '';
    const name = String(r.title ?? '');
    const blob = `${name} ${tree} ${r.product_category ?? ''}`;
    const species = speciesOf(blob);
    if (!species) continue; // drops the wild-bird-seed rows
    const brand = String(r.brand ?? '').trim();
    if (!brand || JUNK_BRAND.test(brand)) continue;
    if (out.has(gtin)) continue;
    out.set(gtin, {
      gtin,
      brand,
      name,
      species,
      category: TREAT.test(blob) ? 'treat' : 'food',
      url: String(r.url ?? '') || undefined,
      image: String(r.image_url ?? '') || undefined,
    });
  }
  return [...out.values()];
}

function walmartBlocks(raw: unknown): string[] {
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
    return parsed.filter((b): b is { values: unknown } => typeof b === 'object' && b !== null && 'values' in b).map((b) => String(b.values));
  }
  return [String(parsed)];
}

/**
 * Walmart identity-only rows to enrich, diverse across brands, up to `limit`. Streams the
 * 823 MB file. `url` intentionally omitted so enrich() takes the search→scrape route.
 */
export async function walmartCandidates(path: string, limit: number): Promise<Candidate[]> {
  const out: Candidate[] = [];
  const perBrand = new Map<string, number>();
  const FOODISH = /food|treat|kibble|chew|biscuit|dry|wet|topper|jerky|dental|formula|recipe|stew|pate|dinner/i;

  for await (const o of streamJsonArray<Record<string, unknown>>(path)) {
    const gtin = String(o.gtin ?? o.upc ?? '').trim();
    if (!/^\d{8}$|^\d{12,14}$/.test(gtin)) continue;
    const brand = String(o.brand ?? '').trim();
    if (!brand || JUNK_BRAND.test(brand)) continue;
    const name = String(o.product_name ?? '').trim();
    if (!name || !FOODISH.test(name)) continue;

    // already has ingredients? skip — those are already built into the catalog.
    const toks = walmartBlocks(o.ingredients_full).join(' ').split(/[,;]/).filter((t) => t.trim().length > 1);
    if (toks.length >= 5) continue;

    const blob = `${name} ${o.category_path ?? ''} ${o.breadcrumb_text ?? ''}`;
    const species = speciesOf(blob);
    if (!species) continue;

    // Spread across brands so one mega-brand doesn't eat the whole budget.
    const seen = perBrand.get(brand.toLowerCase()) ?? 0;
    if (seen >= 8) continue;
    perBrand.set(brand.toLowerCase(), seen + 1);

    out.push({ gtin, brand, name: name.slice(0, 70), species, category: TREAT.test(blob) ? 'treat' : 'food' });
    if (out.length >= limit) break;
  }
  return out;
}
