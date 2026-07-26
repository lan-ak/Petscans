/**
 * Firecrawl enrichment → catalog insert.
 *
 * Turns identity-only rows (GTIN + brand + name, no ingredients) into complete catalog
 * products by fetching the ingredient list from the web, then INSERT OR IGNORE into the
 * same `catalog.sqlite` the build produces. Two fetch routes:
 *   - `url` present (e.g. a Chewy PDP): scrape it directly.
 *   - no `url` (e.g. a Walmart identity row): search `brand + name`, scrape the best
 *     non-marketplace result. This is the app's old Serper→Firecrawl path, run offline.
 *
 * Same request shape as PetScans/Services/FirecrawlService.swift. Same GTIN gates and
 * ingredient normalisation as the build cascade, so enriched rows are indistinguishable
 * from built ones. Spend is capped against the Firecrawl credit budget.
 */

import { DatabaseSync } from 'node:sqlite';
import { canonical, isShippable } from './gtin';

export interface Candidate {
  gtin: string;
  brand: string;
  name: string;
  species: 'dog' | 'cat';
  category: 'food' | 'treat';
  /** PDP to scrape ingredients from. */
  url?: string;
  /** Real product image, when the source carries one (Chewy does). */
  image?: string;
}

const FC = 'https://api.firecrawl.dev/v1';

// Credit costs (Firecrawl): scrape+JSON extract = ~5, search = ~2.
const COST_SCRAPE = 5;
const COST_SEARCH = 2;

// Never scrape these for ingredients — thin listings / walls / irrelevant.
const BAD_HOST = /amazon\.|walmart\.|reddit\.|youtube\.|ebay\.|pinterest\.|facebook\./i;

const SPANISH = /\b(para (perros|gatos)|comida|h[uú]meda|paquete|alimento|golosinas|sabor|carne|pollo|arroz|subproductos)\b/i;
const VAGUE = /derivatives of vegetable origin|meat and animal derivatives|various sugars|derivatives of|oils and fats|cereals\b/i;

const EXTRACT_BODY = (url: string) => ({
  url,
  formats: ['extract'],
  extract: {
    prompt:
      'Extract the pet food product details from this page. name: full product name. brand. ingredients: EVERY ingredient from the complete list (pet food has 25-50+); do not truncate. Return ingredients as an array of strings.',
    schema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        brand: { type: 'string' },
        ingredients: { type: 'array', items: { type: 'string' } },
      },
      required: ['name', 'ingredients'],
    },
  },
});

async function creditsRemaining(key: string): Promise<number> {
  try {
    const r = await fetch(`${FC}/team/credit-usage`, { headers: { Authorization: `Bearer ${key}` } });
    const j = (await r.json()) as { data?: { remaining_credits?: number } };
    return j.data?.remaining_credits ?? 0;
  } catch {
    return 0;
  }
}

async function scrapeIngredients(key: string, url: string): Promise<string[]> {
  const r = await fetch(`${FC}/scrape`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify(EXTRACT_BODY(url)),
  });
  const j = (await r.json().catch(() => ({}))) as { data?: { extract?: { ingredients?: unknown } } };
  const ing = j.data?.extract?.ingredients;
  return Array.isArray(ing) ? ing.map(String) : [];
}

async function search(key: string, query: string): Promise<string[]> {
  const r = await fetch(`${FC}/search`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ query, limit: 5 }),
  });
  const j = (await r.json().catch(() => ({}))) as { data?: { url?: string }[] };
  return (j.data ?? []).map((d) => d.url ?? '').filter(Boolean);
}

/** Comma-join → tokens the way IngredientMatcher expects; null if unusable. */
function normalizeIngredients(list: string[]): { text: string; n: number } | null {
  const joined = list.join(', ');
  if (SPANISH.test(joined) || VAGUE.test(joined)) return null;
  const tokens = joined
    .split(/[,;]/)
    .map((t) => t.trim())
    .filter((t) => t.length > 1);
  if (tokens.length < 5) return null;
  return { text: tokens.join(', '), n: tokens.length };
}

export interface EnrichResult {
  attempted: number;
  inserted: number;
  skippedGtin: number;
  skippedNoIngredients: number;
  creditsSpentEst: number;
  creditsRemainingStart: number;
  creditsRemainingEnd: number;
}

export async function enrich(
  candidates: Candidate[],
  opts: { key: string; dbPath: string; budget: number; concurrency?: number; onLog?: (s: string) => void },
): Promise<EnrichResult> {
  const { key, dbPath, budget } = opts;
  const conc = Math.min(opts.concurrency ?? 4, 25); // cap kept under the Firecrawl plan's concurrency limit (Standard = 50)
  const log = opts.onLog ?? (() => {});

  const startRemaining = await creditsRemaining(key);
  const floor = Math.max(0, startRemaining - budget);

  const db = new DatabaseSync(dbPath);
  const insert = db.prepare(
    `INSERT OR IGNORE INTO products (gtin, name, brand, image_url, ingredients, species, category, n_ingredients, tier)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const existing = new Set<string>(
    (db.prepare('SELECT gtin FROM products').all() as { gtin: string }[]).map((r) => r.gtin),
  );

  let spent = 0;
  const res: EnrichResult = {
    attempted: 0,
    inserted: 0,
    skippedGtin: 0,
    skippedNoIngredients: 0,
    creditsSpentEst: 0,
    creditsRemainingStart: startRemaining,
    creditsRemainingEnd: startRemaining,
  };

  // Pre-filter to shippable, not-already-present GTINs so we never spend on junk.
  const queue: Candidate[] = [];
  for (const c of candidates) {
    const g = canonical(c.gtin);
    if (!g || !isShippable(g)) {
      res.skippedGtin++;
      continue;
    }
    if (existing.has(g)) continue;
    queue.push({ ...c, gtin: g });
  }
  // Size variants of one product (18/34/47-lb of the same bag) share a PDP and therefore
  // share an ingredient list, so scrape each url once and fan the result out to every GTIN
  // on it. A Chewy pull runs ~5 GTINs per url, so this is the difference between covering
  // 61% of a batch and all of it — and reusing the scrape is more correct than re-fetching
  // a page we already read. Candidates with no url keep the one-at-a-time search route.
  interface WorkItem {
    url?: string;
    candidates: Candidate[];
  }
  const byUrl = new Map<string, Candidate[]>();
  const work: WorkItem[] = [];
  for (const c of queue) {
    const u = c.url && !BAD_HOST.test(c.url) ? c.url : undefined;
    if (!u) {
      work.push({ candidates: [c] });
      continue;
    }
    const group = byUrl.get(u);
    if (group) {
      group.push(c);
    } else {
      const started = [c];
      byUrl.set(u, started);
      work.push({ url: u, candidates: started });
    }
  }
  log(
    `queue: ${queue.length} shippable new GTINs across ${work.length} fetches ` +
      `(budget ${budget} credits, floor ${floor})`,
  );

  let i = 0;
  let stop = false;

  async function worker(): Promise<void> {
    while (!stop) {
      const idx = i++;
      if (idx >= work.length) return;
      // Local budget guard: reserve worst-case (search + 2 scrapes) before dispatch.
      if (spent + COST_SEARCH + 2 * COST_SCRAPE > budget) {
        stop = true;
        return;
      }
      const item = work[idx];
      res.attempted += item.candidates.length;

      let list: string[] = [];
      try {
        if (item.url) {
          spent += COST_SCRAPE;
          list = await scrapeIngredients(key, item.url);
        } else {
          const c = item.candidates[0];
          spent += COST_SEARCH;
          const urls = (await search(key, `${c.brand} ${c.name} ingredients`)).filter((u) => !BAD_HOST.test(u));
          for (const u of urls.slice(0, 2)) {
            spent += COST_SCRAPE;
            list = await scrapeIngredients(key, u).catch(() => []);
            if (list.length >= 5) break;
          }
        }
      } catch {
        list = [];
      }

      const norm = normalizeIngredients(list);
      if (!norm) {
        res.skippedNoIngredients += item.candidates.length;
        continue;
      }
      const tier = norm.n >= 20 ? 'A' : 'B';
      for (const c of item.candidates) {
        // image_url is for the *image*. Fall back to the PDP only when the source gave us
        // nothing better (Walmart identity rows), never in preference to a real image.
        const image = (c.image ?? c.url ?? '').slice(0, 300);
        insert.run(c.gtin, c.name.slice(0, 120), c.brand.slice(0, 60), image, norm.text, c.species, c.category, norm.n, tier);
        res.inserted++;
      }
      if (res.inserted % 25 === 0) log(`  inserted ${res.inserted} (attempted ${res.attempted}, ~${spent} credits)`);
    }
  }

  await Promise.all(Array.from({ length: conc }, () => worker()));

  // Refresh meta.count and stamp the enrich source.
  const count = (db.prepare('SELECT count(*) c FROM products').get() as { c: number }).c;
  db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('count', String(count));
  db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)').run('enriched_at', new Date().toISOString());
  db.close();

  res.creditsSpentEst = spent;
  res.creditsRemainingEnd = await creditsRemaining(key);
  return res;
}
