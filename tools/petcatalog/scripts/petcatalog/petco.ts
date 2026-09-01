/**
 * Petco (petco.com) — the last big US retailer the catalog had never swept, and the one that
 * closes the private-label gap.
 *
 * House brands are systematically missing from a catalog built on Walmart + Chewy + PetSmart:
 * WholeHearted held 4 rows, Good Lovin' and Reddy none at all. They are absent for a structural
 * reason, not an accident of coverage — a retailer's own brand is sold nowhere else, so no other
 * source can supply it.
 *
 * Petco is also the richest US page in the sweep. Its PDP carries a JSON-LD ProductGroup whose
 * `hasVariant` list gives one real GTIN per size, the full ingredient string, and — uniquely
 * among the US sources — a `guaranteedAnalysis` string in AAFCO's own wording ("Crude Protein
 * (Min.) 24 %, Crude Fat (Min.) 14 %, …"). That last field is the one the catalog has never
 * had for any US product, and it arrives here for the same one credit as the ingredients.
 *
 * rawHtml + parse for the reasons in intl.ts: the GTINs are in embedded JSON, so an extraction
 * schema returns Petco's internal sku instead and every row dies at `isShippable`.
 */

import { BlockedError, GoneError, type HarvestRecord } from './harvest';

const FC = 'https://api.firecrawl.dev/v2';
const HOST = 'https://www.petco.com';

async function firecrawl(key: string, url: string, timeoutMs = 90_000): Promise<string> {
  const r = await fetch(`${FC}/scrape`, {
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

async function firecrawlMap(key: string, search: string, limit = 5000): Promise<string[]> {
  const r = await fetch(`${FC}/map`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ url: HOST, search, limit }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (!r.ok) throw new Error(`firecrawl map HTTP ${r.status}`);
  const j = (await r.json()) as { links?: ({ url?: string } | string)[]; data?: { links?: ({ url?: string } | string)[] } };
  const links = j.links ?? j.data?.links ?? [];
  return links.map((l) => (typeof l === 'string' ? l : (l.url ?? ''))).filter(Boolean);
}

export interface PetcoTarget {
  url: string;
  id: string;
}

/**
 * Petco declares no sitemap, so discovery is /map. The house brands get their own search terms
 * rather than relying on the generic ones to surface them — they are the point of this adapter,
 * and a generic "dog food" search returns national brands first.
 */
const PETCO_TERMS = [
  'wholehearted dog food', 'wholehearted cat food', 'good lovin dog treats', 'reddy dog',
  'so phresh', 'wholehearted puppy', 'wholehearted kitten',
  'dry dog food', 'wet dog food', 'dry cat food', 'wet cat food',
  'dog treats', 'cat treats', 'puppy food', 'kitten food', 'grain free dog food',
];

export async function petcoTargets(key: string): Promise<PetcoTarget[]> {
  const seen = new Map<string, PetcoTarget>();
  for (const term of PETCO_TERMS) {
    for (const raw of await firecrawlMap(key, term)) {
      const url = raw.split('?')[0];
      const m = url.match(/^https:\/\/www\.petco\.com\/product\/([a-z0-9-]+)$/);
      if (!m) continue;
      if (!seen.has(m[1])) seen.set(m[1], { url, id: m[1] });
    }
  }
  return [...seen.values()];
}

/** og:title is HTML-escaped; the catalog stores display text. */
function decodeEntities(t: string): string {
  return t
    .replace(/&amp;/g, '&')
    .replace(/&#0?39;|&apos;|&rsquo;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

/** Dog/cat consumables only — Petco also sells fish, reptile and small-animal food. */
const CONSUMABLE = /food|treat|kibble|topper|chew|biscuit|dental|jerky|snack|milk|formula/i;
const SPECIES = /\b(dog|puppy|canine|cat|kitten|feline)\b/i;

export function parsePetco(html: string): HarvestRecord[] {
  const s = html.replace(/\\"/g, '"').replace(/\\u0026/g, '&');

  // The ingredient string is the first element of the `ingredients` array inside the PDP's
  // ingredients panel. Anything shorter than a real label is a placeholder.
  const ingredients = (s.match(/"ingredients":\["([^"]{20,})"/)?.[1] ?? '').replace(/\s+/g, ' ').trim();
  if (!ingredients) return [];

  const brand = s.match(/"brand":\s*\{\s*"@type":\s*"Brand",\s*"name":\s*"([^"]+)"/)?.[1] ?? '';
  const category = s.match(/"category":\s*"([^"]+)"/)?.[1] ?? '';
  const name =
    s.match(/<meta\s+property="og:title"\s+content="([^"]+)"/)?.[1] ??
    s.match(/"@type":\s*"ProductGroup"[^]{0,600}?"name":\s*"([^"]+)"/)?.[1] ??
    '';
  if (!brand || !name) return [];

  const blob = `${name} ${category}`;
  if (!CONSUMABLE.test(blob) || !SPECIES.test(blob)) return [];

  // guaranteedAnalysis is an array parallel to the variants, mostly nulls with one real string;
  // the recipe is shared across sizes, so the first non-null applies to all of them.
  const ga = s.match(/"guaranteedAnalysis":\[([^\]]*)\]/)?.[1] ?? '';
  const gaText = (ga.match(/"([^"]{20,})"/)?.[1] ?? '').replace(/\s+/g, ' ').trim();

  const image = s.match(/"image":\s*\[\s*"([^"]+)"/)?.[1];

  const gtins = [...new Set([...s.matchAll(/"gtin\d*":\s*"(\d{8,14})"/g)].map((m) => m[1]))];
  return gtins.map((gtin) => ({
    gtin,
    brand,
    // og:title is HTML, so `&` arrives as `&amp;` — it reaches the app's product list verbatim.
    name: decodeEntities(name).replace(/\s*\|\s*Petco\s*$/i, '').trim(),
    ingredients,
    image,
    categoryPath: category,
    source: 'petco',
    ...(gaText ? { analysis: { guaranteedAnalysis: gaText } } : {}),
  }));
}

export function fetchPetco(key: string) {
  return async (t: PetcoTarget): Promise<HarvestRecord[]> => parsePetco(await firecrawl(key, t.url));
}
