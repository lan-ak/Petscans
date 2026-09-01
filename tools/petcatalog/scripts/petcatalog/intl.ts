/**
 * International retailers — Pets at Home (UK) and Petbarn (AU).
 *
 * The catalog was US/CA-only: a probe for the brands that dominate those two markets found
 * Wainwright's, Harringtons, Burns, Bakers, Winalot, James Wellbeloved, Arden Grange,
 * Black Hawk, Advance, Ivory Coat, Optimum and Supercoat all at zero rows. This file is the
 * whole of that gap.
 *
 * Both sites are JS-rendered and neither serves a usable ingredient list to a plain fetch, so
 * every page goes through Firecrawl. What matters for cost is *which* Firecrawl: the obvious
 * route is `formats:['json']` with an extraction schema, and it is the wrong one on three
 * counts. It costs 5 credits a page against rawHtml's 1; it truncated a 22-ingredient list to
 * 9 and then to 4 on consecutive runs of the same URL; and on both sites it returned the
 * retailer's internal SKU as the barcode ("P71341", "144406") because the real EAN is not in
 * the visible text. Every one of those rows would have died at `isShippable`.
 *
 * The EANs are in the page, in embedded JSON the extractor never reads — `barcodeDetails` on
 * Pets at Home, JSON-LD `gtin` and a `barcode` attribute on Petbarn. So both adapters do what
 * petsmart/petvalu/rens already do: pull rawHtml once and parse it deterministically. Same
 * data, a fifth of the price, and no run-to-run drift.
 *
 * Both markets use EAN-13 (GS1 prefix 50 UK, 93 AU), which `isRetailIssued` already accepts.
 */

import { BlockedError, GoneError, fetchText, type HarvestRecord } from './harvest';

const FC = 'https://api.firecrawl.dev/v2';

/** Shared Firecrawl rawHtml fetch. Mirrors petvalu.ts — same status-code contract. */
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

/** Firecrawl /map — URL discovery for a site with no usable sitemap. */
async function firecrawlMap(key: string, url: string, search: string, limit = 5000): Promise<string[]> {
  const r = await fetch(`${FC}/map`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ url, search, limit }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (!r.ok) throw new Error(`firecrawl map HTTP ${r.status}`);
  const j = (await r.json()) as { links?: ({ url?: string } | string)[]; data?: { links?: ({ url?: string } | string)[] } };
  const links = j.links ?? j.data?.links ?? [];
  return links.map((l) => (typeof l === 'string' ? l : (l.url ?? ''))).filter(Boolean);
}

/**
 * The page is JSON embedded in a JS string literal, so every quote arrives escaped. Both
 * parsers work on the unescaped text; at <2 MB a page, doing it once up front is cheaper
 * than escaping every pattern.
 */
function unescapeEmbedded(html: string): string {
  return html.replace(/\\"/g, '"').replace(/\\u0026/g, '&');
}

export interface IntlTarget {
  url: string;
  id: string;
}

/* ------------------------------------------------------------------ Pets at Home (UK) */

const PAH_HOST = 'https://www.petsathome.com';

/**
 * Pets at Home declares no sitemap (robots.txt is `Allow: /` with no Sitemap line), so
 * discovery is Firecrawl /map. One search term does not reach the whole catalog, so several
 * run and the union is deduped.
 *
 * A PDP is `/product/<slug>/<code>`. `/product/listing/...` is a category page wearing the
 * same prefix and is the one thing that must be excluded.
 */
export async function petsathomeTargets(key: string): Promise<IntlTarget[]> {
  const terms = ['dog food', 'cat food', 'dog treats', 'cat treats', 'dry dog food', 'wet cat food', 'puppy food', 'kitten food'];
  const seen = new Map<string, IntlTarget>();
  for (const t of terms) {
    for (const raw of await firecrawlMap(key, PAH_HOST, t)) {
      const url = raw.split('?')[0];
      if (!/^https:\/\/www\.petsathome\.com\/product\/[^/]+\/[A-Za-z0-9]+$/.test(url)) continue;
      if (url.includes('/product/listing/')) continue;
      const id = url.split('/').pop()!;
      if (!seen.has(id)) seen.set(id, { url, id });
    }
  }
  return [...seen.values()];
}

/** `"analyticalConstituents":{"Protein":"30%",...}` — the object form, not the flat string. */
function pahAnalysis(s: string): Record<string, string> {
  const m = s.match(/"analyticalConstituents":\{([^}]*)\}/);
  if (!m) return {};
  const out: Record<string, string> = {};
  for (const kv of m[1].matchAll(/"([^"]+)":"([^"]*)"/g)) {
    if (kv[2] && !/^not stated$/i.test(kv[2])) out[kv[1]] = kv[2];
  }
  return out;
}

export function parsePetsathome(html: string): HarvestRecord[] {
  const s = unescapeEmbedded(html);

  const name = s.match(/"productName":"([^"]+)"/)?.[1] ?? '';
  const brand = s.match(/"brand":\["([^"]+)"\]/)?.[1] ?? s.match(/"brand":\{"@type":"Brand","name":"([^"]+)"\}/)?.[1] ?? '';
  const composition = s.match(/"composition":"([^"]{20,})"/)?.[1] ?? '';
  if (!name || !brand || !composition) return [];

  const petType = s.match(/"petType":"([^"]*)"/)?.[1] ?? '';
  const categoryType = s.match(/"categoryType":"([^"]*)"/)?.[1] ?? '';
  const groups = [...s.matchAll(/"categories":\[\{"content":"([^"]+)"/g)].map((m) => m[1]);
  const categoryPath = [petType, ...groups, categoryType].filter(Boolean).join(' ');

  const image = s.match(/"image":\["([^"]+)"/)?.[1];
  const analysis = pahAnalysis(s);
  const lifeStage = groups.find((g) => /puppy|kitten|adult|senior|junior/i.test(g));

  // One record per barcode: a PDP carries every size variant, and all sizes of a Pets at Home
  // product share one recipe, so the composition applies to each.
  const gtins = [...new Set([...s.matchAll(/"barcodeDetails":\[\{"value":"(\d{8,14})"/g)].map((m) => m[1]))];
  return gtins.map((gtin) => ({
    gtin,
    brand,
    name,
    ingredients: composition.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim(),
    image,
    categoryPath,
    source: 'petsathome',
    ...(Object.keys(analysis).length ? { analysis } : {}),
    ...(lifeStage ? { lifeStage } : {}),
  }));
}

export function fetchPetsathome(key: string) {
  return async (t: IntlTarget): Promise<HarvestRecord[]> => parsePetsathome(await firecrawl(key, t.url));
}

/* ------------------------------------------------------------------------ Petbarn (AU) */

const PETBARN_SITEMAP = 'https://www.petbarn.com.au/media/sitemap/au/sitemap.xml';

/** Slugs worth paying for: dog/cat consumables. The sitemap also carries fish, birds and toys. */
const PETBARN_KEEP = /(^|-)(dog|puppy|cat|kitten)(-|$)/i;
const PETBARN_FOOD = /(food|treat|kibble|biscuit|chew|dental|jerky|topper|meal|dinner|pate|loaf|roll|raw|milk)/i;

function locs(xml: string): string[] {
  return [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim());
}

/** Petbarn publishes a real sitemap index, so discovery here is free. */
export async function petbarnTargets(): Promise<IntlTarget[]> {
  const index = await fetchText(PETBARN_SITEMAP, { timeoutMs: 60_000 });
  const seen = new Map<string, IntlTarget>();
  for (const child of locs(index).filter((u) => /sitemap-\d/.test(u))) {
    for (const url of locs(await fetchText(child, { timeoutMs: 120_000 }))) {
      const slug = url.split('/p/')[1];
      if (!slug || !PETBARN_KEEP.test(slug) || !PETBARN_FOOD.test(slug)) continue;
      if (!seen.has(slug)) seen.set(slug, { url: url.split('?')[0], id: slug });
    }
  }
  return [...seen.values()];
}

/** `{"__typename":"AttributeValue","code":"ingredients","value":"Turkey Meal; Rice; ..."}` */
function petbarnAttr(s: string, code: string): string {
  const m = s.match(new RegExp(`"code":"${code}","value":"([^"]*)"`)) ?? s.match(new RegExp(`"value":"([^"]*)","code":"${code}"`));
  return m?.[1] ?? '';
}

export function parsePetbarn(html: string): HarvestRecord[] {
  const s = unescapeEmbedded(html);

  const ingredients = petbarnAttr(s, 'ingredients').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  if (!ingredients) return [];

  const name = s.match(/"@type":"Product"[^]{0,400}?"name":"([^"]+)"/)?.[1] ?? s.match(/"name":"([^"]+)"/)?.[1] ?? '';
  const brand = s.match(/"brand":\{"@type":"Brand","name":"([^"]+)"\}/)?.[1] ?? petbarnAttr(s, 'brand_filter');
  if (!name || !brand) return [];

  const categoryPath = [petbarnAttr(s, 'pet_type'), petbarnAttr(s, 'product_category'), petbarnAttr(s, 'sub_category'), s.match(/"category":"([^"]+)"/)?.[1] ?? '']
    .filter(Boolean)
    .join(' ');

  const image = s.match(/"image":"(https:\/\/www\.petbarn\.com\.au\/media[^"]+)"/)?.[1];
  const lifeStage = petbarnAttr(s, 'life_stage');

  // JSON-LD `gtin` is the reliable one; the `barcode` attribute is a fallback for PDPs that
  // omit it. Both are EAN-13.
  const gtins = [
    ...new Set(
      [...s.matchAll(/"gtin(?:13|14|8)?":"(\d{8,14})"/g)].map((m) => m[1]).concat(petbarnAttr(s, 'barcode').match(/\d{8,14}/g) ?? []),
    ),
  ];
  return gtins.map((gtin) => ({
    gtin,
    brand,
    name,
    ingredients,
    image,
    categoryPath,
    source: 'petbarn',
    ...(lifeStage ? { lifeStage } : {}),
  }));
}

export function fetchPetbarn(key: string) {
  return async (t: IntlTarget): Promise<HarvestRecord[]> => parsePetbarn(await firecrawl(key, t.url));
}
