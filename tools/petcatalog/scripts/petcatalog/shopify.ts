/**
 * Shopify storefront adapter — reach brands Chewy's search never surfaces.
 *
 * Several specialty brands (Open Farm, Only Natural Pet, …) don't come through the Chewy
 * brand-search discovery at all, so the catalog carries only a handful of their SKUs. Their
 * own Shopify storefronts, though, expose the one thing the app needs to make a bag
 * scannable: the real UPC, in `variant.barcode`. And it's free — plain JSON, no Firecrawl.
 *
 * This produces the same `Candidate[]` the Chewy path does (real GTIN + product-page url +
 * image), so `enrich` scrapes the ingredient list from the product page and inserts with no
 * special-casing. Ingredients aren't in the Shopify JSON (body_html omits them), which is why
 * we hand the url to enrich rather than inserting here.
 *
 * Scope: only helps brands that (a) run Shopify and (b) populate variant.barcode. Brands on
 * independent-store-only distribution with no barcode published anywhere online (e.g. Fromm)
 * cannot be filled this way — that gap is real and not automatable from the open web.
 */

import type { Candidate } from './enrich';

const CAT = /\bcat\b|kitten|feline/i;
const DOG = /\bdog\b|puppy|canine/i;
const TREAT = /treat|chew|biscuit|jerky|bone|dental|snack|topper|supplement|broth|kefir/i;
// Retailer stores mix in gear/apparel/grooming with no ingredient list — skip so we don't
// waste an enrich scrape on a page that can never yield ingredients.
const NONFOOD = /harness|leash|collar|\bbowl\b|\btoy\b|\bbed\b|crate|carrier|apparel|jacket|\bboot|wipe|shampoo|brush|\bnail\b|\bgear\b|backpack|blanket|towel|mat\b|poop|waste bag|grooming|cologne|perfume|spray|balm/i;

interface ShopifyVariant {
  barcode?: string | null;
}
interface ShopifyProduct {
  handle: string;
  title: string;
  vendor?: string;
  product_type?: string;
  tags?: string[] | string;
  images?: { src?: string }[];
  variants?: ShopifyVariant[];
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** GET + parse JSON with retry/backoff. Large retailer stores rate-limit the rapid
 *  per-product fetches, dropping products silently without this. 429/5xx and timeouts retry. */
async function getJson(url: string, timeoutMs = 20000, attempts = 4): Promise<unknown> {
  for (let a = 0; a < attempts; a++) {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), timeoutMs);
    try {
      const r = await fetch(url, { signal: ac.signal, headers: { 'User-Agent': 'petcatalog/1.0' } });
      if (r.ok) return await r.json();
      if (r.status === 429 || r.status >= 500) throw new Error(String(r.status)); // retry
      return null; // 404 etc. — no point retrying
    } catch {
      if (a === attempts - 1) return null;
      await sleep(600 * (a + 1) + Math.floor(400 * (a + 1) * (url.length % 3) / 2)); // staggered backoff
    } finally {
      clearTimeout(t);
    }
  }
  return null;
}

function speciesOf(text: string): 'dog' | 'cat' | null {
  const c = CAT.test(text);
  const d = DOG.test(text);
  if (c === d) return null; // both or neither → ambiguous, skip
  return c ? 'cat' : 'dog';
}

/** Walk one Shopify storefront and emit a candidate per unique barcoded variant. */
export async function shopifyCandidates(
  brand: string,
  domain: string,
  opts: { onLog?: (s: string) => void } = {},
): Promise<Candidate[]> {
  const log = opts.onLog ?? (() => {});
  const out = new Map<string, Candidate>();

  // 1) list every product handle (Shopify pages 250 at a time; barcode isn't on this
  //    endpoint, so we only take identity here and fetch detail below). `vendor` is the real
  //    manufacturer, so a multi-brand retailer store (e.g. Only Natural Pet) ingests every
  //    brand it carries correctly rather than mislabelling them all as the storefront.
  const listed: { handle: string; title: string; brand: string; blob: string; img?: string }[] = [];
  for (let page = 1; page <= 40; page++) {
    const j = (await getJson(`https://${domain}/products.json?limit=250&page=${page}`)) as { products?: ShopifyProduct[] } | null;
    const prods = j?.products ?? [];
    if (!prods.length) break;
    for (const p of prods) {
      const tags = Array.isArray(p.tags) ? p.tags.join(' ') : p.tags ?? '';
      listed.push({
        handle: p.handle,
        title: p.title,
        brand: (p.vendor ?? '').trim() || brand,
        blob: `${p.title} ${p.product_type ?? ''} ${tags}`,
        img: p.images?.[0]?.src,
      });
    }
  }
  log(`${brand}: ${listed.length} products listed on ${domain}`);

  // 2) per-product detail carries variant.barcode (the UPC). Bounded concurrency so we
  //    don't hammer the storefront.
  let idx = 0;
  async function worker(): Promise<void> {
    while (idx < listed.length) {
      const p = listed[idx++];
      if (NONFOOD.test(p.blob)) continue; // gear/apparel/grooming — no ingredients to fetch
      const species = speciesOf(p.blob);
      if (!species) continue;
      const detail = (await getJson(`https://${domain}/products/${p.handle}.json`)) as { product?: ShopifyProduct } | null;
      const variants = detail?.product?.variants ?? [];
      for (const v of variants) {
        const bc = (v.barcode ?? '').trim();
        if (!/^\d{8}$|^\d{12,14}$/.test(bc)) continue; // needs a real UPC/EAN
        if (out.has(bc)) continue;
        out.set(bc, {
          gtin: bc,
          brand: p.brand,
          name: p.title,
          species,
          category: TREAT.test(p.blob) ? 'treat' : 'food',
          url: `https://${domain}/products/${p.handle}`,
          image: p.img,
        });
      }
    }
  }
  await Promise.all(Array.from({ length: 4 }, () => worker())); // gentle on retailer rate limits

  log(`${brand}: ${out.size} barcoded candidates`);
  return [...out.values()];
}

/**
 * Shopify storefronts to harvest, name → domain. Two kinds, both handled the same way (the
 * real brand comes from each product's `vendor`):
 *   - single-brand stores (Open Farm) — deep coverage of one brand;
 *   - multi-brand independent retailers (Only Natural Pet: 56 vendors, Tomlinson's: 211) —
 *     these carry the MAP-restricted, independent-only brands (Fromm, Rawz, Northwest
 *     Naturals, …) that Chewy-search and the brands' own marketing sites never expose a UPC
 *     for. One retailer sweep fills dozens of otherwise-unreachable brands.
 *
 * Extend by probing `https://<domain>/products/<any-handle>.json` for a non-empty
 * variant.barcode; independent pet retailers on Shopify are the richest sources.
 */
export const SHOPIFY_BRANDS: Record<string, string> = {
  'Open Farm': 'openfarmpet.com',
  'Only Natural Pet': 'onlynaturalpet.com',
  "Tomlinson's": 'tomlinsons.com',
};
