/**
 * Pet Valu (petvalu.ca) — Next.js App Router behind Cloudflare.
 *
 * The only one of the four that costs real money. Cloudflare 403s plain HTTP outright, so
 * every page goes through Firecrawl at ~1 credit each, and a PDP is a 3.1 MB React Server
 * Component payload. Sweeping all ~3,555 dog/cat food products would run ~3,600 credits.
 *
 * Which is why this adapter filters by brand *before* fetching — the only one of the four
 * where that is possible. Pet Valu publishes `brand-listing.xml`, and a product's URL slug is
 * prefixed with its brand's slug, so brand is known from the sitemap alone. Restricting to
 * brands the catalog lacks (Performatrin ×4, Oven-Baked Tradition, Canadian Naturals, Big
 * Country Raw, …) buys most of Pet Valu's unique value for roughly a quarter of the spend.
 *
 * Inside the RSC payload the product is a clean `productData` object — brand, name, per-size
 * `variant[].upc`, pet type, category. Long strings are not inlined: `"ingredients":"$2dec"`
 * is a pointer into the Flight chunk table (`2dec:T53f,<payload>`, length in hex), so the
 * ingredient list has to be resolved through that table. That indirection is the whole reason
 * this file is longer than the other two.
 */

import { BlockedError, GoneError, fetchText, type HarvestRecord } from './harvest';

const HOST = 'www.petvalu.ca';
const BRAND_SITEMAP = `https://${HOST}/sitemaps/sitemap/brand-listing.xml`;
const PRODUCT_SITEMAP = `https://${HOST}/sitemaps/sitemap/productsitemap.xml`;

export interface PetvaluTarget {
  slug: string;
  url: string;
  brandSlug: string;
}

/** Firecrawl is the only way in; every fetch here is proxied through it. */
async function firecrawl(key: string, url: string, timeoutMs = 90_000): Promise<string> {
  const r = await fetch('https://api.firecrawl.dev/v2/scrape', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ url, formats: ['rawHtml'], timeout: timeoutMs }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (r.status === 404) throw new GoneError('HTTP 404');
  if (r.status === 429) throw new BlockedError(60_000, 'firecrawl rate limit');
  if (!r.ok) throw new Error(`firecrawl HTTP ${r.status}`);
  const j = (await r.json()) as { data?: { rawHtml?: string } };
  const html = j.data?.rawHtml;
  if (!html) throw new Error('firecrawl returned no rawHtml');
  return html;
}

function locs(xml: string): string[] {
  return [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim());
}

/** Brand slugs Pet Valu publishes, longest first so `performatrin-ultra` wins over `performatrin`. */
export async function petvaluBrandSlugs(key: string): Promise<string[]> {
  const xml = await firecrawl(key, BRAND_SITEMAP);
  return locs(xml)
    .map((u) => u.split('/brand/')[1] ?? '')
    .filter(Boolean)
    .sort((a, b) => b.length - a.length);
}

/**
 * Attribute each product url to a brand by slug prefix.
 *
 * Pet Valu drops "and" when slugifying a product but keeps it in the brand slug
 * (`bailey-and-bella` → `bailey-bella-velvet-bolster-bed`), which is the only systematic
 * mismatch; trying the elided form too takes prefix matching from 95% to effectively all.
 */
export async function petvaluTargets(key: string, brandSlugs: string[]): Promise<PetvaluTarget[]> {
  const xml = await firecrawl(key, PRODUCT_SITEMAP);
  const forms: [string, string][] = brandSlugs.map((b) => [b, b.replace(/-and-/g, '-')]);

  const out: PetvaluTarget[] = [];
  for (const url of locs(xml)) {
    const slug = (url.split('/product/')[1] ?? '').split('/')[0];
    if (!slug) continue;
    const hit = forms.find(([b, elided]) => slug === b || slug.startsWith(b + '-') || slug === elided || slug.startsWith(elided + '-'));
    if (hit) out.push({ slug, url, brandSlug: hit[0] });
  }
  return out;
}

/**
 * Resolve the React Flight chunk table: `<id>:T<hexLength>,<payload>`.
 *
 * Payload length is declared in hex rather than delimited, so a value containing a comma or
 * quote (every ingredient list does) can only be read by slicing exactly that many chars.
 */
function flightRefs(html: string): Map<string, string> {
  const refs = new Map<string, string>();
  for (const m of html.matchAll(/([0-9a-f]{1,4}):T([0-9a-f]+),/g)) {
    const len = parseInt(m[2], 16);
    refs.set(m[1], html.slice(m.index + m[0].length, m.index + m[0].length + len));
  }
  return refs;
}

interface ProductData {
  brand: string;
  name: string;
  ingredients: string;
  pet: string;
  web: string;
  ctype: string;
  upcs: string[];
  image?: string;
}

/** Pull `productData` out of the RSC stream. Returns null for non-product pages. */
export function parsePetvalu(html: string): ProductData | null {
  const refs = flightRefs(html);
  const at = html.indexOf('productData\\":');
  const start = at >= 0 ? at : html.indexOf('productData":');
  if (start < 0) return null;

  // The blob is JSON embedded in a JS string literal, so it arrives double-escaped. Unescape a
  // generous window rather than the whole 3 MB page.
  const s = html.slice(start, start + 60_000).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
  const str = (k: string): string => s.match(new RegExp(`"${k}":"([^"]*)"`))?.[1] ?? '';

  let ingredients = str('ingredients');
  if (ingredients.startsWith('$')) ingredients = refs.get(ingredients.slice(1)) ?? '';

  return {
    brand: str('brand'),
    name: str('name'),
    // `u003c…u003e` is how the escaped HTML survives the round trip; strip both spellings.
    ingredients: ingredients
      .replace(/u003c[^u]*?u003e/g, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\\u0026|u0026/g, '&')
      .replace(/\s+/g, ' ')
      .trim(),
    pet: (s.match(/"petTypePrimary":\[([^\]]*)\]/)?.[1] ?? '').replace(/"/g, ' ').trim(),
    web: str('webCategory').replace(/\\u0026|u0026/g, '&'),
    ctype: str('consumableType'),
    upcs: [...new Set([...s.matchAll(/"upc":\["?(\d{8,14})/g)].map((m) => m[1]))],
    image: s.match(/"assets":\["([^"]+)"/)?.[1],
  };
}

/** Dog/cat consumables only — Pet Valu's Food/Treats also covers bird, fish and small pet. */
function isDogCatFood(p: ProductData): boolean {
  if (!/^Food|^Treats/.test(p.web)) return false;
  return /\b(Dog|Cat)\b/.test(p.pet);
}

export function fetchPetvalu(key: string) {
  return async (t: PetvaluTarget): Promise<HarvestRecord[]> => {
    const p = parsePetvalu(await firecrawl(key, t.url));
    if (!p || !isDogCatFood(p)) return [];

    // `name` is only the recipe ("Grain-Free Senior Recipe Small Bite Dog Food"); the brand
    // lives beside it, so join them into the label the app will show.
    const name = `${p.brand} ${p.name}`.replace(/\s+/g, ' ').trim();
    return p.upcs.map((gtin) => ({
      gtin,
      brand: p.brand,
      name,
      ingredients: p.ingredients,
      image: p.image,
      categoryPath: `${p.pet} ${p.web} ${p.ctype}`.trim(),
      source: 'petvalu',
    }));
  };
}

/** Firecrawl credits left on the plan. */
export async function firecrawlCredits(key: string): Promise<number> {
  const r = await fetchText('https://api.firecrawl.dev/v2/team/credit-usage', {
    headers: { Authorization: `Bearer ${key}` },
    timeoutMs: 20_000,
  });
  return (JSON.parse(r) as { data?: { remainingCredits?: number } }).data?.remainingCredits ?? 0;
}
