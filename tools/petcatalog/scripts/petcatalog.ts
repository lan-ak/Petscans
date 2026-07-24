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

const REPO_ROOT = resolve(__dirname, '../../..');
const DEFAULT_OUT = resolve(REPO_ROOT, 'PetScans/Data/catalog.sqlite');

/** Read the Firecrawl key from backend/.dev.vars (never committed). */
function firecrawlKey(): string {
  const vars = readFileSync(resolve(REPO_ROOT, 'backend/.dev.vars'), 'utf8');
  const m = vars.match(/^FIRECRAWL_API_KEY=(.+)$/m);
  if (!m) throw new Error('FIRECRAWL_API_KEY not found in backend/.dev.vars');
  return m[1].trim().replace(/^"|"$/g, '');
}

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
`;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const cmd = argv[0];

  if (!cmd || cmd === 'help' || cmd === '--help') {
    console.log(help());
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
