/**
 * PetScans catalog CLI.
 *
 *   cd tools/petcatalog
 *   npm install
 *   npm run petcatalog -- build --source "../../Walmart Data/BrightData_july232026.json"
 *
 * Produces PetScans/Data/catalog.sqlite, the barcode -> ingredients table bundled in the
 * app. Everything downstream of the ingredient string (matching, scoring) already runs
 * on-device, so this file is the whole difference between a 60-second scan and an
 * instant one.
 */

import { resolve } from 'node:path';
import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { build } from './petcatalog/build';
import { enrich, type Candidate } from './petcatalog/enrich';
import { chewyCandidates, walmartCandidates } from './petcatalog/candidates';
import { collectChewy } from './petcatalog/chewy-collect';
import { shopifyCandidates, SHOPIFY_BRANDS } from './petcatalog/shopify';
import { packInPlace } from './petcatalog/pack';

const REPO_ROOT = resolve(__dirname, '../../..');
const DEFAULT_OUT = resolve(REPO_ROOT, 'PetScans/Data/catalog.sqlite');

/** Read a key from backend/.dev.vars (never committed). */
function devVar(name: string): string {
  const vars = readFileSync(resolve(REPO_ROOT, 'backend/.dev.vars'), 'utf8');
  const m = vars.match(new RegExp(`^${name}=(.+)$`, 'm'));
  if (!m) throw new Error(`${name} not found in backend/.dev.vars`);
  return m[1].trim().replace(/^"|"$/g, '');
}

const firecrawlKey = (): string => devVar('FIRECRAWL_API_KEY');
const brightDataKey = (): string => devVar('BRIGHTDATA_API_KEY');

/** Urls already sent to Bright Data. Committed, so the skip-list is shared. */
const LEDGER = resolve(REPO_ROOT, 'tools/petcatalog/collected-chewy-urls.txt');

function arg(argv: string[], name: string): string | undefined {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? argv[i + 1] : undefined;
}

function pct(n: number, total: number): string {
  return total ? `${((100 * n) / total).toFixed(1)}%` : '—';
}

function help(): string {
  return `
petcatalog — build the bundled product catalog

  build    Stream the vendor JSON through the filter cascade and write catalog.sqlite

    --source <path>      vendor JSON array (required)
    --out <path>         output sqlite (default: PetScans/Data/catalog.sqlite)
    --include-tier-c     also write 5-9 ingredient rows (default: excluded — usually truncated)

  collect-chewy  Discover Chewy PDPs (Firecrawl) -> scrape them (Bright Data) -> write the
                 records whose GTIN the catalog lacks. Skips urls already collected, so
                 repeat runs only reach for new stock.

    --storefront us|ca|both   which Chewy site (default: both)
    --pages <n>               listing pages to walk per source (default: 1, ~40 urls each)
    --limit <n>               max NEW urls to collect this run (default: 250)
    --brands                  discover via specialty-brand search (Royal Canin, Hill's, …)
                              instead of the broad food categories — targets the Walmart gap
    --query <term>            discover via one ad-hoc Chewy search (targets a specific product)
    --dry-run                 discover only: write the url list, skip Bright Data, keep the ledger
    --urls <file>             skip discovery; collect from a JSON url list (e.g. a --dry-run output).
                              Batch a full sweep: discover once, then loop this with --limit chunks
    --out <path>              JSON for enrich to read (default: /tmp/chewy-new.json)
    --db <path>               catalog to diff against (default: PetScans/Data/catalog.sqlite)

  collect-shopify  Reach specialty brands Chewy-search never surfaces, via their Shopify
                 storefronts — variant.barcode gives a real UPC for free (no Firecrawl).
                 Writes candidates for enrich to fetch ingredients from.

    --brand <name> --domain <host>   one ad-hoc store (else the built-in SHOPIFY_BRANDS)
    --out <path>              candidate JSON (default: /tmp/shopify-new.json)

  enrich   Fetch ingredients for identity-only rows and insert them into catalog.sqlite

    --source chewy|walmart|file  candidate source (required). 'file' reads a pre-built
                                 Candidate[] JSON (e.g. from collect-shopify) verbatim.
    --budget <credits>        Firecrawl spend ceiling (required)
    --file <path>             candidate JSON (default: ~/Downloads/chewy products.json)
    --out <path>              catalog sqlite to insert into
    --limit <n>               max candidates (walmart scan only)

  pack     Compress the ingredient column (raw-DEFLATE) + drop n_ingredients + VACUUM, in
           place. Idempotent, round-trip verified. Halves the shipped file; the app inflates
           natively via Apple's Compression framework. Run before shipping a build.

    --db <path>               catalog to pack (default: PetScans/Data/catalog.sqlite)

Typical growth loop:

  npm run petcatalog -- collect-chewy --pages 3 --limit 200
  npm run petcatalog -- enrich --source chewy --file /tmp/chewy-new.json --budget 1500

Fill a Shopify specialty brand, then shrink for shipping:

  npm run petcatalog -- collect-shopify --brand "Open Farm" --domain openfarmpet.com
  npm run petcatalog -- enrich --source file --file /tmp/shopify-new.json --budget 800
  npm run petcatalog -- pack
`;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const cmd = argv[0];

  if (!cmd || cmd === 'help' || cmd === '--help') {
    console.log(help());
    return;
  }

  if (cmd === 'collect-chewy') {
    const out = resolve(process.cwd(), arg(argv, 'out') ?? '/tmp/chewy-new.json');
    const storefront = (arg(argv, 'storefront') ?? 'both') as 'us' | 'ca' | 'both';
    if (!['us', 'ca', 'both'].includes(storefront)) {
      console.error('--storefront must be us | ca | both');
      process.exitCode = 2;
      return;
    }
    const r = await collectChewy({
      fcKey: firecrawlKey(),
      bdKey: brightDataKey(),
      dbPath: resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT),
      ledgerPath: LEDGER,
      out,
      storefront,
      pages: Number(arg(argv, 'pages') ?? '1'),
      limit: Number(arg(argv, 'limit') ?? '250'),
      discovery: argv.includes('--brands') ? 'brands' : 'categories',
      query: arg(argv, 'query'),
      dryRun: argv.includes('--dry-run'),
      urlsFile: arg(argv, 'urls') ? resolve(process.cwd(), arg(argv, 'urls')!) : undefined,
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    console.log('');
    console.log(`urls collected    : ${r.urlsDiscovered}`);
    console.log(`urls skipped      : ${r.urlsSkipped}  (already in ledger)`);
    console.log(`records returned  : ${r.recordsReturned}`);
    console.log(`in target scope   : ${r.inScope}`);
    console.log(`already in catalog: ${r.alreadyHeld}`);
    console.log(`NEW GTINs written : ${r.newGtins}  -> ${r.outPath}`);
    console.log('');
    if (r.newGtins) {
      console.log(`next: npm run petcatalog -- enrich --source chewy --file ${r.outPath} --budget <credits>`);
      console.log('');
    }
    return;
  }

  if (cmd === 'pack') {
    // Compress the ingredient column (raw-DEFLATE) + drop n_ingredients + VACUUM, in place.
    // Idempotent; verifies every row round-trips before swapping. Run before shipping a build.
    const db = resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT);
    const before = statSync(db).size;
    const r = packInPlace(db, (s) => process.stderr.write(s + '\n'));
    const after = statSync(db).size;
    console.log('');
    console.log(r.migrated ? 'packed (ingredients → raw-DEFLATE, n_ingredients dropped)' : 'already packed — no change');
    console.log(`rows              : ${r.rows}`);
    console.log(`round-trip fails  : ${r.mismatches}`);
    console.log(`size              : ${(before / 1e6).toFixed(1)} MB -> ${(after / 1e6).toFixed(1)} MB`);
    console.log('');
    return;
  }

  if (cmd === 'collect-shopify') {
    const out = resolve(process.cwd(), arg(argv, 'out') ?? '/tmp/shopify-new.json');
    // --brand "Open Farm" --domain openfarmpet.com for an ad-hoc store, else the registry.
    const oneBrand = arg(argv, 'brand');
    const oneDomain = arg(argv, 'domain');
    const targets: [string, string][] = oneBrand && oneDomain
      ? [[oneBrand, oneDomain]]
      : Object.entries(SHOPIFY_BRANDS);

    const all: Candidate[] = [];
    for (const [brand, domain] of targets) {
      const c = await shopifyCandidates(brand, domain, { onLog: (s) => process.stderr.write(s + '\n') });
      all.push(...c);
    }
    writeFileSync(out, JSON.stringify(all, null, 2));
    console.log('');
    console.log(`brands scanned    : ${targets.length}`);
    console.log(`barcoded candidates: ${all.length}  -> ${out}`);
    console.log('');
    if (all.length) {
      console.log(`next: npm run petcatalog -- enrich --source file --file ${out} --budget <credits>`);
      console.log('');
    }
    return;
  }

  if (cmd === 'enrich') {
    const source = arg(argv, 'source'); // 'chewy' | 'walmart' | 'file'
    const out = arg(argv, 'out') ?? DEFAULT_OUT;
    const budget = Number(arg(argv, 'budget') ?? '0');
    const limit = Number(arg(argv, 'limit') ?? '2000');
    if (!source || !budget) {
      console.error('enrich requires --source chewy|walmart|file and --budget <credits>');
      process.exitCode = 2;
      return;
    }
    let cands;
    if (source === 'chewy') {
      cands = chewyCandidates(resolve(process.cwd(), arg(argv, 'file') ?? `${process.env.HOME}/Downloads/chewy products.json`));
    } else if (source === 'walmart') {
      process.stderr.write('scanning Walmart file for identity-only rows…\n');
      cands = await walmartCandidates(resolve(process.cwd(), arg(argv, 'file') ?? `${REPO_ROOT}/Walmart Data/BrightData_july232026.json`), limit);
    } else if (source === 'file') {
      // A pre-built Candidate[] JSON (e.g. from collect-shopify): GTIN + url already resolved.
      const file = arg(argv, 'file');
      if (!file) {
        console.error('enrich --source file requires --file <candidates.json>');
        process.exitCode = 2;
        return;
      }
      cands = JSON.parse(readFileSync(resolve(process.cwd(), file), 'utf8')) as Candidate[];
    } else {
      console.error(`unknown --source ${source}`);
      process.exitCode = 2;
      return;
    }
    process.stderr.write(`${cands.length} candidates from ${source}\n`);

    const r = await enrich(cands, {
      key: firecrawlKey(),
      dbPath: resolve(process.cwd(), out),
      budget,
      concurrency: Number(arg(argv, 'concurrency') ?? '5'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    console.log('');
    console.log(`source            : ${source}`);
    console.log(`attempted         : ${r.attempted}`);
    console.log(`INSERTED          : ${r.inserted}`);
    console.log(`skipped (gtin)    : ${r.skippedGtin}`);
    console.log(`skipped (no ingr) : ${r.skippedNoIngredients}`);
    console.log(`credits (est spend): ${r.creditsSpentEst}`);
    console.log(`credits remaining : ${r.creditsRemainingStart} -> ${r.creditsRemainingEnd}`);
    return;
  }

  if (cmd !== 'build') {
    console.error(`Unknown command: ${cmd}`);
    console.error(help());
    process.exitCode = 2;
    return;
  }

  const source = arg(argv, 'source');
  if (!source) {
    console.error('--source is required');
    process.exitCode = 2;
    return;
  }

  const out = arg(argv, 'out') ?? DEFAULT_OUT;
  const started = Date.now();

  process.stderr.write('streaming vendor data…\n');
  const r = await build({
    source: resolve(process.cwd(), source),
    out: resolve(process.cwd(), out),
    includeTierC: argv.includes('--include-tier-c'),
    onProgress: (seen) => process.stderr.write(`\r  ${seen.toLocaleString()} records`),
  });
  process.stderr.write('\r');

  const lines: string[] = [];
  lines.push('');
  lines.push(`Source records: ${r.seen.toLocaleString()}`);
  lines.push('');
  lines.push('Rejected:');
  for (const [reason, n] of Object.entries(r.rejected)) {
    if (n) lines.push(`  ${reason.padEnd(20)} ${String(n).padStart(7)}  ${pct(n, r.seen)}`);
  }
  lines.push('');
  lines.push(`WRITTEN: ${r.written.toLocaleString()} products  (${pct(r.written, r.seen)} of source)`);
  lines.push('');
  lines.push(`  tier      ${JSON.stringify(r.byTier)}`);
  lines.push(`  species   ${JSON.stringify(r.bySpecies)}`);
  lines.push(`  category  ${JSON.stringify(r.byCategory)}`);
  lines.push(`  images    ${r.withImage.toLocaleString()} (${pct(r.withImage, r.written)})`);
  lines.push('');
  lines.push(`  top brands: ${r.topBrands.map(([b, n]) => `${b}(${n})`).join(', ')}`);
  lines.push('');
  lines.push(`Wrote ${out}  —  ${(r.bytes / 1e6).toFixed(1)} MB  in ${((Date.now() - started) / 1000).toFixed(0)}s`);
  lines.push('');
  console.log(lines.join('\n'));
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
