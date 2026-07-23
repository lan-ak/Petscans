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
import { build } from './petcatalog/build';

const REPO_ROOT = resolve(__dirname, '../../..');
const DEFAULT_OUT = resolve(REPO_ROOT, 'PetScans/Data/catalog.sqlite');

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
