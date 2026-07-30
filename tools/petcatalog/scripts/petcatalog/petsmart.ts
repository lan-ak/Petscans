/**
 * PetSmart US + CA — Next.js storefront over an Algolia index, fronted by Akamai.
 *
 * The storefront's own React app talks to a public proxy, `/api/cwea/v2/product/{id}/base`,
 * which answers with the complete product: every size variant, each with its own `upc`, plus
 * a `description` whose "Ingredients:" block is the full label. One request per PDP yields
 * ~1.7 scannable barcodes. No key, no Firecrawl.
 *
 * The catch is Akamai. Sustained parallel fetching earns a site-wide 403 — not per-endpoint,
 * not per-domain: petsmart.com and petsmart.ca go dark together, including ordinary browser
 * page loads. Measured: ~1,000 requests at concurrency 14 tripped it, and it cleared on its
 * own after ~45 minutes. So the defaults here are deliberately slow (concurrency 2, ~900 ms
 * apart ≈ 2 req/s, a full 7,600-PDP sweep in about an hour), and 403 raises `BlockedError` so
 * the harness parks the whole run for the ban window instead of burning the queue against it.
 *
 * `--via firecrawl` routes the same URLs through Firecrawl, which is not subject to the ban.
 * It costs a credit per fetch, so it is the retry path for stragglers rather than the default.
 * Firecrawl strips HTML tags from the JSON it returns, which breaks `JSON.parse` on ~7% of
 * responses; those land in `.failed` and are simply retried direct.
 */

import { BlockedError, GoneError, fetchJson, fetchText, sitemapLocs, type HarvestRecord } from './harvest';

export type Storefront = 'us' | 'ca';

const SITE = {
  us: { host: 'www.petsmart.com', locale: 'en-US' },
  ca: { host: 'www.petsmart.ca', locale: 'en-CA' },
} as const;

/** The three category roots that are dog/cat food or treats. The rest is toys, gear, pharmacy. */
const FOOD_ROOTS = new Set(['dog/food', 'dog/treats', 'cat/food-and-treats']);

/** 45 min — the observed Akamai ban window, plus a little slack. */
export const PETSMART_BAN_MS = 47 * 60_000;

interface Variant {
  name?: string;
  brand?: { name?: string };
  description?: string;
  upc?: string;
  media?: { type?: string; url?: string }[];
}
interface ProductBase {
  data?: { variants?: Record<string, Variant> };
}

export interface PetsmartTarget {
  id: string;
  storefront: Storefront;
  categoryPath: string;
}

/**
 * Every dog/cat food+treat PDP id in a storefront's sitemaps.
 *
 * `categoryPath` feeds both species and food/treat inference downstream, so it is built from
 * the species root plus the *sub*category — never the root alone. PetSmart files all feline
 * consumables under `cat/food-and-treats`, and that literal string contains "treats", which
 * makes the treat detector fire on every wet cat food in the catalogue. The subcategory
 * (`wet-food`, `dry-food`, `treats`, `bones-bully-sticks-and-chews`) says which it actually is.
 */
export async function petsmartTargets(sf: Storefront): Promise<PetsmartTarget[]> {
  const { host } = SITE[sf];
  const index = await sitemapLocs(`https://${host}/sitemap_index.xml`);
  // Only the numbered page sitemaps carry PDPs; the image/video ones repeat the same urls.
  const pages = index.filter((u) => /\/sitemap_\d+\.xml$/.test(u));

  const out = new Map<string, PetsmartTarget>();
  for (const page of pages) {
    for (const url of await sitemapLocs(page)) {
      if (!url.endsWith('.html')) continue;
      const path = url.split(`${host}/`)[1] ?? '';
      const segments = path.split('/');
      const root = segments.slice(0, 2).join('/');
      if (!FOOD_ROOTS.has(root)) continue;
      const m = url.match(/-(\d{3,8})\.html$/);
      if (!m || out.has(m[1])) continue;
      const species = segments[0]; // 'dog' | 'cat'
      const sub = (segments[2] ?? '').replace(/-/g, ' ');
      out.set(m[1], { id: m[1], storefront: sf, categoryPath: `${species} ${sub}`.trim() });
    }
  }
  return [...out.values()];
}

/**
 * Pull the ingredient statement out of the marketing description.
 *
 * The description is a single HTML blob of labelled sections — `<b>Ingredients: </b>…` — but
 * the label is sometimes `<strong>`, sometimes bare, and Firecrawl strips the tags entirely,
 * newlines and all. So we flatten to text and cut at the next label rather than at a tag.
 *
 * Two traps, both hit in practice:
 *   - the colon is required. Marketing copy says "real salmon is the first ingredient and a
 *     high quality source of protein", which an optional-colon pattern happily matches,
 *     yielding a paragraph of prose that scores as if it were a label.
 *   - a description can contain the word twice ("...limited ingredients" in Key Benefits,
 *     then the real "Ingredients:" block), so we take the candidate that actually reads like
 *     a list — comma density separates a label from a sentence far better than position does.
 */
const NEXT_LABEL =
  /(?:Caloric Content|Calorie Content|Guaranteed Analysis|Feeding Instructions?|Feeding Guidelines?|Nutritional (?:Benefits|Options)|Health Consideration|Item Number|Life ?Stage|Breed Size|Food Type|Flavou?r|Weight|Brand)\s*:/i;

export function ingredientsFromDescription(html: string): string {
  const text = html
    .replace(/<[^>]+>/g, '\n')
    .replace(/&#38;|&amp;/g, '&')
    .replace(/&(nbsp|reg|trade|copy|quot|apos|frasl|ndash|mdash|#\d+);?/g, ' ');

  let best = '';
  let bestCommas = 0;
  for (const m of text.matchAll(/\bIngredients?\s*:\s*\n?([\s\S]{30,6000}?)(?:\n\s*(?=[A-Z][A-Za-z ]{2,30}\s*:)|$)/gi)) {
    const body = m[1].split(NEXT_LABEL)[0].replace(/\s+/g, ' ').trim();
    const commas = (body.slice(0, 600).match(/,/g) ?? []).length;
    if (commas > bestCommas) {
      best = body;
      bestCommas = commas;
    }
  }
  return best;
}

function toRecords(base: ProductBase, t: PetsmartTarget): HarvestRecord[] {
  const variants = base.data?.variants ?? {};
  const out: HarvestRecord[] = [];
  for (const v of Object.values(variants)) {
    const gtin = (v.upc ?? '').trim();
    if (!gtin) continue;
    out.push({
      gtin,
      brand: (v.brand?.name ?? '').trim(),
      name: (v.name ?? '').trim(),
      ingredients: ingredientsFromDescription(v.description ?? ''),
      image: v.media?.find((m) => m.type === 'image')?.url,
      categoryPath: t.categoryPath,
      source: `petsmart-${t.storefront}`,
    });
  }
  return out;
}

export function petsmartUrl(t: PetsmartTarget): string {
  const { host, locale } = SITE[t.storefront];
  return `https://${host}/api/cwea/v2/product/${t.id}/base?locale=${locale}`;
}

/** Direct fetch. 403 means Akamai banned the IP, so park the whole run. */
export async function fetchPetsmart(t: PetsmartTarget): Promise<HarvestRecord[]> {
  const base = await fetchJson<ProductBase>(petsmartUrl(t), {
    blockOn: [403, 429],
    blockBackoffMs: PETSMART_BAN_MS,
    headers: { Referer: `https://${SITE[t.storefront].host}/${t.categoryPath.replace(' ', '/')}/` },
  });
  return toRecords(base, t);
}

/** Same product, fetched through Firecrawl — immune to the ban, costs ~1 credit. */
export function fetchPetsmartViaFirecrawl(key: string) {
  return async (t: PetsmartTarget): Promise<HarvestRecord[]> => {
    const r = await fetch('https://api.firecrawl.dev/v2/scrape', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: petsmartUrl(t), formats: ['rawHtml'], timeout: 45_000 }),
    });
    if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
    if (!r.ok) throw new Error(`firecrawl HTTP ${r.status}`);
    const j = (await r.json()) as { data?: { rawHtml?: string } };
    const raw = j.data?.rawHtml ?? '';
    return toRecords(JSON.parse(raw) as ProductBase, t);
  };
}

/**
 * Is the storefront answering us, or is Akamai holding the door shut?
 *
 * The distinction that matters is "did a server reply", not "did the probe find a product".
 * Catalogues differ between the two sites — the US id this used to probe with 404s on
 * petsmart.ca — so treating any failure as a ban made a healthy CA storefront look banned and
 * sent the sweep into a 90-minute poll for a block that was never there. A 404 is a perfectly
 * good answer; only a 403 or a dead socket means we are shut out.
 */
export async function petsmartReachable(sf: Storefront): Promise<boolean> {
  try {
    await fetchText(`https://${SITE[sf].host}/api/cwea/v2/product/96922/base?locale=${SITE[sf].locale}`, {
      timeoutMs: 20_000,
      blockOn: [403, 429],
      blockBackoffMs: 0,
    });
    return true;
  } catch (err) {
    // A 404 is the server answering, which is all we asked. Anything else — 403, timeout,
    // dead socket — counts as shut out.
    return err instanceof GoneError;
  }
}

/**
 * Block until the storefront answers again, polling rather than sleeping a flat ban window.
 *
 * The window is nominally ~45 minutes but is not a promise — it varies, and a sweep that just
 * sleeps the full nominal time idles for however long it overshot. Both storefronts sit behind
 * the same Akamai tenancy, so finishing a US sweep can leave CA banned on entry; polling every
 * few minutes gets the next leg moving the moment the door reopens.
 */
export async function waitForPetsmart(
  sf: Storefront,
  opts: { maxWaitMs?: number; pollMs?: number; onLog?: (s: string) => void } = {},
): Promise<boolean> {
  const maxWait = opts.maxWaitMs ?? 90 * 60_000;
  const poll = opts.pollMs ?? 5 * 60_000;
  const log = opts.onLog ?? (() => {});
  const deadline = Date.now() + maxWait;

  if (await petsmartReachable(sf)) return true;
  log(`petsmart-${sf}: blocked (403) — polling every ${Math.round(poll / 60_000)} min until it clears`);
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, poll));
    if (await petsmartReachable(sf)) {
      log(`petsmart-${sf}: reachable again after ${Math.round((maxWait - (deadline - Date.now())) / 60_000)} min`);
      return true;
    }
    log(`petsmart-${sf}: still blocked, ${Math.round((deadline - Date.now()) / 60_000)} min left before giving up`);
  }
  return false;
}
