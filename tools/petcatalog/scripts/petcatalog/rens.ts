/**
 * Ren's Pets (renspets.com) — Salesforce Commerce Cloud.
 *
 * The cheapest source in the toolkit: no Firecrawl, no Bright Data, no bot wall. SFCC's
 * `Product-Variation` controller answers with a 13 KB JSON document per product carrying
 * everything the catalog needs — brand, name, a dedicated `ingredients` field, and the image.
 * A full 5,621-product census completes in ~15 minutes at concurrency 10 with no throttling.
 *
 * The UPC is the one thing SFCC does not model as a field. Ren's leaks it anyway, third in the
 * comma-separated `pageKeywords` meta tag:
 *
 *   "Acana,Acana Adult - FD Morsels - Duck - 227 g,064992715625,,,131777,D404-71562,Dog-Food…"
 *
 * so we take the first token that looks like a GTIN rather than trusting the position — the
 * brand or product name occasionally contains a number, and an empty slot shifts the rest.
 *
 * ~26% of food products publish no UPC at all and ~23% carry an ingredient list too short to
 * score; both are dropped downstream by the `extract` cascade rather than here, so the reject
 * counts stay visible in one place.
 */

import { fetchJson, sitemapLocs, type HarvestRecord } from './harvest';

const HOST = 'www.renspets.com';
const SITEMAPS = [`https://${HOST}/sitemap_0-product.xml`, `https://${HOST}/sitemap_1-product.xml`];

/** SFCC `primaryCategory` slugs that are dog/cat food or treats. Everything else is gear. */
const FOOD_CATEGORY = /^(dog|cat)-(food|treats|dental)|^freeze-dried-(dog|cat)-treats|^(cat-food-treats|dog-training-treats)$/;

interface RensProduct {
  brand?: string;
  productName?: string;
  ingredients?: string;
  pageKeywords?: string;
  primaryCategory?: string;
  images?: { large?: { url?: string }[] };
}

export interface RensTarget {
  pid: string;
  url: string;
}

/** Every product id in the sitemaps. Ids are the trailing number of the PDP slug. */
export async function rensTargets(): Promise<RensTarget[]> {
  const out = new Map<string, RensTarget>();
  for (const sm of SITEMAPS) {
    for (const url of await sitemapLocs(sm)) {
      const m = url.match(/-(\d{3,8})\.html$/);
      if (m) out.set(m[1], { pid: m[1], url });
    }
  }
  return [...out.values()];
}

function upcFromKeywords(keywords: string): string {
  for (const raw of keywords.split(',')) {
    const t = raw.trim();
    if (/^\d{8}$|^\d{12,14}$/.test(t)) return t;
  }
  return '';
}

export async function fetchRens(t: RensTarget): Promise<HarvestRecord[]> {
  const { product } = await fetchJson<{ product?: RensProduct }>(
    `https://${HOST}/on/demandware.store/Sites-CA-Site/en_CA/Product-Variation?pid=${t.pid}`,
  );
  if (!product) return [];

  const category = (product.primaryCategory ?? '').trim();
  if (!FOOD_CATEGORY.test(category)) return []; // ledgered as done — never fetched twice

  const gtin = upcFromKeywords(product.pageKeywords ?? '');
  if (!gtin) return [];

  return [
    {
      gtin,
      brand: (product.brand ?? '').trim(),
      name: (product.productName ?? '').trim(),
      ingredients: (product.ingredients ?? '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim(),
      image: product.images?.large?.[0]?.url,
      // extract() reads species off this; the SFCC slug already leads with dog-/cat-.
      categoryPath: category.replace(/-/g, ' '),
      source: 'rens',
    },
  ];
}
