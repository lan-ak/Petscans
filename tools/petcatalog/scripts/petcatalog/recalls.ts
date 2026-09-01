/**
 * FDA animal & veterinary recalls -> recalls.json, matched against the catalog's brands.
 *
 * The catalog scores a product purely on its ingredient list, which cannot express the single
 * most useful safety fact about a food: that this brand was recalled, and why. This adapter
 * collects that.
 *
 * Getting the whole table takes one non-obvious step. The page ships only its first 10 rows in
 * HTML and loads the rest through Drupal's datatables AJAX, so a plain scrape sees 2026 and
 * nothing else. There is an XLSX export (`datatables-data/download`), but it returns a fixed
 * 2024-2025 slice and ignores its own `page` parameter — the 2026 rows visible on the page are
 * missing from it. Driving the length selector to 100 and re-reading is what actually returns
 * the complete set: 59 recalls, 2019 to date.
 *
 * Older recalls live in FDA's separate wayback archive and are deliberately out of scope — the
 * live table is the window where a recall still concerns a product someone can buy today.
 */

import { BlockedError } from './harvest';

const FC = 'https://api.firecrawl.dev/v2';
const PAGE = 'https://www.fda.gov/animal-veterinary/safety-health/recalls-withdrawals';

export interface Recall {
  date: string;
  brands: string[];
  product: string;
  reason: string;
  company: string;
  url?: string;
}

/** Set the datatable's page length to 100, wait for the AJAX, then read the rendered table. */
async function fetchRecallTable(key: string): Promise<string> {
  const r = await fetch(`${FC}/scrape`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      url: PAGE,
      formats: ['markdown'],
      actions: [
        { type: 'wait', milliseconds: 2500 },
        {
          type: 'executeJavascript',
          script:
            "const s=document.querySelector('select[name=datatable_length]'); if(s){s.value='100'; s.dispatchEvent(new Event('change',{bubbles:true}));}",
        },
        { type: 'wait', milliseconds: 4000 },
      ],
    }),
  });
  if (r.status === 402) throw new BlockedError(60_000, 'firecrawl credits exhausted');
  if (!r.ok) throw new Error(`firecrawl HTTP ${r.status}`);
  const j = (await r.json()) as { data?: { markdown?: string } };
  const md = j.data?.markdown;
  if (!md) throw new Error('firecrawl returned no markdown');
  return md;
}

/** `| 08/28/2026 | [Northwest Naturals](url) | Chicken Recipe | reason | company | | |` */
export function parseRecalls(md: string): Recall[] {
  const out: Recall[] = [];
  for (const line of md.split('\n')) {
    if (!/^\|\s*\d{2}\/\d{2}\/\d{4}\s*\|/.test(line)) continue;
    const cells = line.split('|').slice(1, -1).map((c) => c.trim());
    if (cells.length < 5) continue;
    const [date, brandCell, product, reason, company] = cells;

    // The brand cell is a markdown link whose text may list several brands.
    const link = brandCell.match(/\[([^\]]*)\]\(([^)]*)\)/);
    const brandText = link ? link[1] : brandCell;
    const brands = brandText
      .split(/,\s*/)
      .map((b) => b.trim())
      .filter(Boolean);

    out.push({ date, brands, product, reason, company, ...(link ? { url: link[2] } : {}) });
  }
  return out;
}

export async function collectRecalls(key: string): Promise<Recall[]> {
  return parseRecalls(await fetchRecallTable(key));
}

/**
 * Brand strings are written differently on each side ("Blue Ridge Beef" vs "Blue Ridge"), so
 * compare on a punctuation- and case-free form and accept a containment match either way.
 *
 * Containment has to start at the shorter side's first word, and that word must carry some
 * identity. Without the second rule the catalog's junk brand "PRODUCTS" matched the recall for
 * "3-D Pet Products"; with a word-count rule instead, the real "Nutrena" / "Nutrena Loyall
 * Life" pair was lost. A stoplist of category nouns keeps both cases right.
 */
const GENERIC = new Set([
  'products', 'product', 'pet', 'pets', 'food', 'foods', 'company', 'brands', 'brand', 'farms',
  'farm', 'naturals', 'natural', 'family', 'premium', 'health', 'nutrition', 'diet', 'raw', 'the',
]);
/**
 * Match recall brands to catalog brands.
 */
export function normaliseBrand(b: string): string {
  return b
    .toLowerCase()
    .replace(/['’]/g, '')
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function matchBrands(recalls: Recall[], catalogBrands: string[]): Map<string, Recall[]> {
  const byNorm = new Map<string, string>();
  for (const b of catalogBrands) byNorm.set(normaliseBrand(b), b);

  const hits = new Map<string, Recall[]>();
  for (const r of recalls) {
    for (const rb of r.brands) {
      const n = normaliseBrand(rb);
      if (!n) continue;
      for (const [cn, original] of byNorm) {
        const shorter = n.length <= cn.length ? n : cn;
        const longer = n.length <= cn.length ? cn : n;
        const head = shorter.split(' ')[0];
        const contains = !GENERIC.has(head) && longer.split(' ')[0] === head && longer.startsWith(shorter);
        if (cn !== n && !contains) continue;
        const list = hits.get(original) ?? [];
        if (!list.some((x) => x.date === r.date && x.product === r.product)) list.push(r);
        hits.set(original, list);
      }
    }
  }
  return hits;
}
