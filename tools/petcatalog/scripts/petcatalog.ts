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
import { readFileSync } from 'node:fs';
import { build } from './petcatalog/build';
import { enrich } from './petcatalog/enrich';
import { chewyCandidates, walmartCandidates } from './petcatalog/candidates';
import { collectChewy } from './petcatalog/chewy-collect';

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
    --pages <n>               category pages to walk per category (default: 1, ~40 urls each)
    --limit <n>               max NEW urls to collect this run (default: 250)
    --out <path>              JSON for enrich to read (default: /tmp/chewy-new.json)
    --db <path>               catalog to diff against (default: PetScans/Data/catalog.sqlite)

  enrich   Fetch ingredients for identity-only rows and insert them into catalog.sqlite

    --source chewy|walmart    candidate source (required)
    --budget <credits>        Firecrawl spend ceiling (required)
    --file <path>             candidate JSON (default: ~/Downloads/chewy products.json)
    --out <path>              catalog sqlite to insert into
    --limit <n>               max candidates (walmart scan only)

Typical growth loop:

  npm run petcatalog -- collect-chewy --pages 3 --limit 200
  npm run petcatalog -- enrich --source chewy --file /tmp/chewy-new.json --budget 1500
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

  if (cmd === 'enrich') {
    const source = arg(argv, 'source'); // 'chewy' | 'walmart'
    const out = arg(argv, 'out') ?? DEFAULT_OUT;
    const budget = Number(arg(argv, 'budget') ?? '0');
    const limit = Number(arg(argv, 'limit') ?? '2000');
    if (!source || !budget) {
      console.error('enrich requires --source chewy|walmart and --budget <credits>');
      process.exitCode = 2;
      return;
    }
    let cands;
    if (source === 'chewy') {
      cands = chewyCandidates(resolve(process.cwd(), arg(argv, 'file') ?? `${process.env.HOME}/Downloads/chewy products.json`));
    } else if (source === 'walmart') {
      process.stderr.write('scanning Walmart file for identity-only rows…\n');
      cands = await walmartCandidates(resolve(process.cwd(), arg(argv, 'file') ?? `${REPO_ROOT}/Walmart Data/BrightData_july232026.json`), limit);
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
