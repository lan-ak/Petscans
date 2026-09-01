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
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { build } from './petcatalog/build';
import { enrich, type Candidate } from './petcatalog/enrich';
import { chewyCandidates, walmartCandidates } from './petcatalog/candidates';
import { collectChewy } from './petcatalog/chewy-collect';
import { shopifyCandidates, SHOPIFY_BRANDS } from './petcatalog/shopify';
import { packInPlace } from './petcatalog/pack';
import { clearFailed, harvest, readDone, readFailed, type HarvestResult } from './petcatalog/harvest';
import { fetchRens, rensTargets } from './petcatalog/rens';
import {
  fetchPetsmart,
  fetchPetsmartViaFirecrawl,
  waitForPetsmart,
  petsmartTargets,
  type PetsmartTarget,
  type Storefront,
} from './petcatalog/petsmart';
import { fetchPetvalu, firecrawlCredits, petvaluBrandSlugs, petvaluTargets } from './petcatalog/petvalu';
import { fetchPetbarn, fetchPetsathome, petbarnTargets, petsathomeTargets } from './petcatalog/intl';
import { fetchPetco, petcoTargets } from './petcatalog/petco';
import { collectRecalls, matchBrands } from './petcatalog/recalls';
import { applyImages, fetchImage, imagelessProducts } from './petcatalog/images';
import { applyAnalysis, fetchAnalysis, productsWithoutAnalysis } from './petcatalog/analysis-backfill';
import { ensureAnalysisColumns } from './petcatalog/analysis';
import { ingest } from './petcatalog/ingest';
import { cleanCatalog } from './petcatalog/clean';
import { groupCatalog, ungroupedCount } from './petcatalog/group';

const REPO_ROOT = resolve(__dirname, '../../..');
const DEFAULT_OUT = resolve(REPO_ROOT, 'PetScans/Data/catalog.sqlite');

/** Harvest sidecars (.jsonl/.done/.failed/.status.json) live here — gitignored, resumable. */
const DEFAULT_WORK = resolve(REPO_ROOT, 'tools/petcatalog/harvest');

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

/**
 * Print a warning if the catalog holds rows that grouping has not seen. Search reads
 * product_groups, so those rows resolve on a scan but cannot be found by name — a silence
 * that is easy to ship and hard to notice.
 */
function warnIfUngrouped(dbPath: string): void {
  const n = ungroupedCount(dbPath);
  if (!n) return;
  console.log(`WARNING: ${n.toLocaleString()} products are in no search group and cannot be found by name.`);
  console.log('         run: npm run petcatalog -- group --apply');
  console.log('');
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

  backfill-analysis  Find guaranteed analysis for rows that have none (search -> markdown ->
                     parse). Biggest brands first; ~3 credits/product. Resumable.
    --budget <n>          products to attempt this run (required)
    --no-migrate          never write to the catalog, not even to add its columns
  apply-analysis   Write that harvest onto the catalog. Never overwrites a filled column.

  backfill-images  Find a picture for catalog rows that have none (search -> og:image).
                   Resumable; writes harvest/image-backfill.jsonl. ~3 credits/product.
    --limit <n>           only the first n imageless products
  apply-images     Write that harvest onto the catalog. Only ever fills a blank.

  collect-recalls  FDA animal & veterinary recalls -> recalls.json, matched to catalog brands.
    --out <path>          artifact path (default: harvest/recalls.json)

  collect-petco  Petco (US) via Firecrawl rawHtml, ~1 credit/product. The only US source
                 carrying guaranteed analysis, and the only one with the house brands
                 (WholeHearted, Good Lovin', Reddy).
    --budget <n>          cap the number of products fetched this run

  collect-petsathome  Pets at Home (UK) via Firecrawl rawHtml, ~1 credit/product. Carries
                      analytical constituents alongside ingredients.
    --budget <n>          cap the number of products fetched this run
    --concurrency <n>     parallel fetches (default: 4)

  collect-petbarn  Petbarn (AU). Same shape; discovery is free (sitemap).
    --budget <n>          cap the number of products fetched this run

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

  collect-rens   Census renspets.com (Salesforce Commerce Cloud). Free — no Firecrawl, no
                 bot wall. ~5,600 products in ~15 min. Resumable.

    --work <dir>              harvest sidecar dir (default: tools/petcatalog/harvest)
    --concurrency <n>         parallel fetches (default: 10)
    --retry-failed            re-queue only the ids in rens.failed

  collect-petsmart  Sweep petsmart.com / petsmart.ca via their public product API. Free, but
                 Akamai bans the IP for ~45 min after sustained load, so the defaults are
                 slow on purpose (~2 req/s, ~1 h for a full storefront). A ban parks the run
                 and resumes itself. Resumable.

    --storefront us|ca|both   which site (default: both)
    --via direct|firecrawl    direct is free; firecrawl bypasses the ban at ~1 credit/fetch
    --concurrency <n>         parallel fetches (default: 2 direct, 5 firecrawl)
    --delay <ms>              per-worker pacing (default: 900 direct, 0 firecrawl)
    --retry-failed            re-queue only the ids in petsmart-<sf>.failed
    --max-wait-min <n>        if blocked on entry, poll this long for the ban to lift (default 90)
    --work <dir>              harvest sidecar dir

  collect-petvalu  Scrape petvalu.ca through Firecrawl (Cloudflare blocks everything else),
                 narrowed to brands the catalog holds incompletely — brand is readable from
                 the url slug, so the filter costs nothing and saves ~75% of the spend.
                 Resumable.

    --budget <credits>        hard ceiling on Firecrawl spend (required)
    --min-coverage <ratio>    target brands we hold less than this fraction of (default 0.6).
                              An absent brand is coverage 0, so this subsumes the old
                              absent-or-present test and also catches half-filled brands,
                              which that test excluded forever once a sweep touched them
    --brands <a,b,c>          target these brand slugs only, whatever their coverage
                              (e.g. performatrin-ultra,performatrin-prime)
    --name <harvest>          harvest name / ledger (default: petvalu). Use a distinct name for
                              a top-up so it neither collides with nor re-fetches a full sweep
    --all-brands              ignore the brand filter and sweep every dog/cat food product
    --concurrency <n>         parallel fetches (default: 4)
    --work <dir>              harvest sidecar dir

  ingest   Fold harvested JSONL into catalog.sqlite through the same filter cascade as build
           (valid retail GTIN, >=5 ingredients, unambiguous species). Idempotent.

    --names <a,b,c>           harvest names (default: every .jsonl in --work)
    --work <dir>              harvest sidecar dir
    --db <path>               catalog to insert into
    --dry-run                 report what would land, insert nothing

  clean    Re-audit the shipped catalog and delete rows whose stored ingredient text is
           provably corrupt (template placeholders, or a list split on spaces not commas).
           Dry run by default.

    --db <path>               catalog to audit (default: PetScans/Data/catalog.sqlite)
    --apply                   actually delete (default: report only)

  pack     Compress the ingredient column (raw-DEFLATE) + drop n_ingredients + VACUUM, in
           place. Idempotent, round-trip verified. Halves the shipped file; the app inflates
           natively via Apple's Compression framework. Run before shipping a build.

    --db <path>               catalog to pack (default: PetScans/Data/catalog.sqlite)

  group    Fold size/pack variants of the same recipe into one search listing: writes
           product_groups + products.group_id. Deletes nothing — every GTIN still resolves
           for the scan path. Idempotent. Run AFTER pack, which rebuilds products and drops
           group_id with it. Dry run by default.

    --db <path>               catalog to group (default: PetScans/Data/catalog.sqlite)
    --apply                   actually write the groups (default: report only)

Typical growth loop:

  npm run petcatalog -- collect-chewy --pages 3 --limit 200
  npm run petcatalog -- enrich --source chewy --file /tmp/chewy-new.json --budget 1500

Fill a Shopify specialty brand, then shrink for shipping:

  npm run petcatalog -- collect-shopify --brand "Open Farm" --domain openfarmpet.com
  npm run petcatalog -- enrich --source file --file /tmp/shopify-new.json --budget 800
  npm run petcatalog -- pack
  npm run petcatalog -- group --apply

Retailer sweep (survives sleep/close — see ./harvest.sh, which detaches and holds the
machine awake; every collector resumes from its ledger if it is interrupted):

  ./harvest.sh all                 # rens -> petsmart -> petvalu -> ingest -> pack
  ./harvest.sh status              # progress of whatever is running
`;
}

/** Print the tail of a harvest in one consistent block. */
function reportHarvest(label: string, r: HarvestResult): void {
  console.log('');
  console.log(`${label}`);
  console.log(`  targets           : ${r.total}`);
  console.log(`  skipped (ledger)  : ${r.skippedFromLedger}`);
  console.log(`  fetched this run  : ${r.fetched}`);
  console.log(`  records written   : ${r.records}  -> ${r.jsonlPath}`);
  console.log(`  gone (404)        : ${r.gone}`);
  console.log(`  failed            : ${r.failed}${r.failed ? `  -> ${r.failedPath}` : ''}`);
  if (r.blockedPauses) console.log(`  host blocks ridden: ${r.blockedPauses}`);
  if (r.stopped) console.log('  STOPPED early — re-run the same command to resume.');
  console.log('');
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

  if (cmd === 'collect-rens') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    process.stderr.write('reading renspets sitemaps…\n');
    let targets = await rensTargets();
    if (argv.includes('--retry-failed')) {
      const ids = new Set(readFailed(work, 'rens'));
      targets = targets.filter((t) => ids.has(t.pid));
      clearFailed(work, 'rens');
      process.stderr.write(`retrying ${targets.length} previously failed ids\n`);
    }
    const r = await harvest({
      name: 'rens',
      workDir: work,
      targets,
      idOf: (t) => t.pid,
      fetchOne: fetchRens,
      concurrency: Number(arg(argv, 'concurrency') ?? '10'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest("Ren's Pets", r);
    return;
  }

  if (cmd === 'collect-petsmart') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const sfArg = (arg(argv, 'storefront') ?? 'both') as 'us' | 'ca' | 'both';
    if (!['us', 'ca', 'both'].includes(sfArg)) {
      console.error('--storefront must be us | ca | both');
      process.exitCode = 2;
      return;
    }
    const via = (arg(argv, 'via') ?? 'direct') as 'direct' | 'firecrawl';
    const stores: Storefront[] = sfArg === 'both' ? ['us', 'ca'] : [sfArg];

    for (const sf of stores) {
      const name = `petsmart-${sf}`;
      process.stderr.write(`reading ${name} sitemaps…\n`);
      let targets: PetsmartTarget[] = await petsmartTargets(sf);
      if (argv.includes('--retry-failed')) {
        const ids = new Set(readFailed(work, name));
        targets = targets.filter((t) => ids.has(t.id));
        clearFailed(work, name);
        process.stderr.write(`retrying ${targets.length} previously failed ids\n`);
      }
      if (via === 'direct') {
        // Starting inside an active ban would burn every attempt on the same 403. Wait it out
        // here rather than exiting, so an unattended sweep picks itself up the moment the door
        // reopens instead of idling out a nominal window that may already have passed.
        const ok = await waitForPetsmart(sf, {
          maxWaitMs: Number(arg(argv, 'max-wait-min') ?? '90') * 60_000,
          onLog: (s) => process.stderr.write(s + '\n'),
        });
        if (!ok) {
          process.stderr.write(`${name}: still blocked after the wait window — re-run later, or use --via firecrawl.\n`);
          process.exitCode = 3;
          return;
        }
      }
      const r = await harvest({
        name,
        workDir: work,
        targets,
        idOf: (t) => t.id,
        fetchOne: via === 'firecrawl' ? fetchPetsmartViaFirecrawl(firecrawlKey()) : fetchPetsmart,
        concurrency: Number(arg(argv, 'concurrency') ?? (via === 'firecrawl' ? '5' : '2')),
        delayMs: Number(arg(argv, 'delay') ?? (via === 'firecrawl' ? '0' : '900')),
        onLog: (s) => process.stderr.write(s + '\n'),
      });
      reportHarvest(`PetSmart ${sf.toUpperCase()} (${via})`, r);
      if (r.stopped) return;
    }
    return;
  }

  if (cmd === 'collect-petvalu') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const budget = Number(arg(argv, 'budget') ?? '0');
    if (!budget) {
      console.error('collect-petvalu requires --budget <credits> (every fetch costs one)');
      process.exitCode = 2;
      return;
    }
    const key = firecrawlKey();
    const before = await firecrawlCredits(key);
    process.stderr.write(`firecrawl credits: ${before}\n`);

    // A named harvest keeps a targeted top-up on its own ledger, so it neither collides with a
    // running full sweep nor re-fetches what that sweep already has.
    const harvestName = arg(argv, 'name') ?? 'petvalu';

    const allSlugs = await petvaluBrandSlugs(key);
    // One sitemap read covers every brand; filtering happens on the result, so widening or
    // narrowing the brand set never costs an extra fetch.
    const allTargets = await petvaluTargets(key, allSlugs);

    let slugs = allSlugs;
    const only = arg(argv, 'brands');
    if (only) {
      const want = new Set(only.split(',').map((s) => s.trim()).filter(Boolean));
      slugs = allSlugs.filter((s) => want.has(s));
      const missing = [...want].filter((w) => !allSlugs.includes(w));
      process.stderr.write(`brands: targeting ${slugs.length} of ${want.size} requested\n`);
      if (missing.length) process.stderr.write(`  not listed by Pet Valu: ${missing.join(', ')}\n`);
      if (!slugs.length) {
        console.error('none of the requested brand slugs exist on petvalu.ca');
        process.exitCode = 2;
        return;
      }
    } else if (!argv.includes('--all-brands')) {
      /**
       * Target by how *completely* we hold a brand, not by whether we hold it at all.
       *
       * The absent-or-present test this replaces had a trap: the moment a sweep pulled the
       * first SKUs of a brand, that brand stopped looking absent and was excluded from every
       * later run — frozen at whatever coverage it happened to reach. Performatrin sat at
       * 74 of 347 listings that way, and only got finished because someone noticed. Brands
       * like Kiwi Kitchens (8 SKUs) were sitting in the same trap behind it.
       *
       * Comparing what the retailer lists against what we hold catches both cases with one
       * rule: an absent brand is simply coverage 0, and a half-filled one is coverage 0.21.
       */
      const minCoverage = Number(arg(argv, 'min-coverage') ?? '0.6');
      const listed = new Map<string, number>();
      for (const t of allTargets) listed.set(t.brandSlug, (listed.get(t.brandSlug) ?? 0) + 1);

      const db = new DatabaseSync(resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT));
      const held = new Map<string, number>();
      for (const r of db
        .prepare("SELECT lower(trim(brand)) b, count(*) c FROM products WHERE brand IS NOT NULL AND trim(brand) <> '' GROUP BY 1")
        .all() as { b: string; c: number }[]) {
        const slug = r.b.replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
        if (slug) held.set(slug, (held.get(slug) ?? 0) + r.c);
      }
      db.close();

      const partial: string[] = [];
      slugs = allSlugs.filter((s) => {
        const n = listed.get(s) ?? 0;
        if (!n) return false; // brand lists nothing we could fetch
        const have = held.get(s) ?? 0;
        const coverage = have / n;
        if (coverage >= minCoverage) return false;
        if (have > 0) partial.push(`${s} ${have}/${n}`);
        return true;
      });
      process.stderr.write(
        `brands: ${allSlugs.length} listed, ${slugs.length} below ${(minCoverage * 100).toFixed(0)}% coverage\n`,
      );
      if (partial.length) {
        // These are exactly the brands the old absent-or-present filter would have skipped.
        process.stderr.write(`  ${partial.length} partially held (the old filter skipped these): ${partial.slice(0, 12).join(', ')}\n`);
      }
    }

    const wanted = new Set(slugs);
    let targets = allTargets.filter((t) => wanted.has(t.brandSlug));
    process.stderr.write(`${targets.length} product urls under those brands\n`);
    // Budget against what is left to fetch, not the whole list: every fetch costs a credit, but
    // ones already in the ledger cost nothing, and counting them would strand the tail.
    const alreadyDone = readDone(work, harvestName);
    const remaining = targets.filter((t) => !alreadyDone.has(t.slug));
    if (alreadyDone.size) {
      process.stderr.write(`${alreadyDone.size} already collected; ${remaining.length} still to fetch\n`);
    }
    if (remaining.length > budget) {
      process.stderr.write(`capping at --budget ${budget} (${remaining.length - budget} left for a later run)\n`);
      targets = remaining.slice(0, budget);
    } else {
      targets = remaining;
    }

    const r = await harvest({
      name: harvestName,
      workDir: work,
      targets,
      idOf: (t) => t.slug,
      fetchOne: fetchPetvalu(key),
      concurrency: Number(arg(argv, 'concurrency') ?? '4'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest(`Pet Valu${only ? ` (${only})` : ''}`, r);
    console.log(`  credits: ${before} -> ${await firecrawlCredits(key)}`);
    console.log('');
    return;
  }

  if (cmd === 'backfill-analysis' || cmd === 'apply-analysis') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const dbPath = resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT);
    const name = arg(argv, 'name') ?? 'analysis-backfill';
    const jsonl = resolve(work, `${name}.jsonl`);

    if (cmd === 'apply-analysis') {
      const r = applyAnalysis(jsonl, dbPath);
      console.log('');
      console.log(`records read      : ${r.read.toLocaleString()}`);
      console.log(`macros written    : ${r.updated.toLocaleString()}`);
      console.log(`unusable          : ${r.unusable.toLocaleString()}`);
      console.log('');
      return;
    }

    const budget = Number(arg(argv, 'budget') ?? '0');
    if (!budget) {
      console.error('backfill-analysis requires --budget <products> — a full sweep would cost more than a month of credits');
      process.exitCode = 2;
      return;
    }

    const key = firecrawlKey();
    const before = await firecrawlCredits(key);
    process.stderr.write(`firecrawl credits: ${before}\n`);

    // The columns normally arrive with the first ingest, but the backfill can legitimately be
    // the first thing run against a catalog, and productsWithoutAnalysis reads them.
    // --no-migrate keeps this a pure reader, for when someone else is using the catalog.
    if (!argv.includes('--no-migrate')) {
      const migrateDb = new DatabaseSync(dbPath);
      if (ensureAnalysisColumns(migrateDb)) process.stderr.write('added guaranteed-analysis columns to products\n');
      migrateDb.close();
    }

    const targets = productsWithoutAnalysis(dbPath, budget);
    process.stderr.write(`${targets.length} products without macros, biggest brands first\n`);

    const r = await harvest({
      name,
      workDir: work,
      targets,
      idOf: (t) => t.gtin,
      fetchOne: fetchAnalysis(key),
      concurrency: Number(arg(argv, 'concurrency') ?? '4'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest('Guaranteed-analysis backfill', r);
    console.log(`  credits: ${before} -> ${await firecrawlCredits(key)}`);
    console.log(`  next: npm run petcatalog -- apply-analysis`);
    console.log('');
    return;
  }

  if (cmd === 'backfill-images' || cmd === 'apply-images') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const dbPath = resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT);
    const name = arg(argv, 'name') ?? 'image-backfill';
    const jsonl = resolve(work, `${name}.jsonl`);

    if (cmd === 'apply-images') {
      const r = applyImages(jsonl, dbPath);
      console.log('');
      console.log(`records read      : ${r.read.toLocaleString()}`);
      console.log(`images written    : ${r.updated.toLocaleString()}`);
      console.log(`already had one   : ${r.missingRow.toLocaleString()}`);
      console.log('');
      return;
    }

    const key = firecrawlKey();
    const before = await firecrawlCredits(key);
    process.stderr.write(`firecrawl credits: ${before}\n`);

    const limit = Number(arg(argv, 'limit') ?? '0');
    const targets = imagelessProducts(dbPath, limit || undefined);
    process.stderr.write(`${targets.length} products have no image\n`);

    const r = await harvest({
      name,
      workDir: work,
      targets,
      idOf: (t) => t.gtin,
      fetchOne: fetchImage(key),
      concurrency: Number(arg(argv, 'concurrency') ?? '4'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest('Image backfill', r);
    console.log(`  credits: ${before} -> ${await firecrawlCredits(key)}`);
    console.log(`  next: npm run petcatalog -- apply-images`);
    console.log('');
    return;
  }

  if (cmd === 'collect-recalls') {
    const key = firecrawlKey();
    const outPath = resolve(process.cwd(), arg(argv, 'out') ?? resolve(DEFAULT_WORK, 'recalls.json'));
    const recalls = await collectRecalls(key);

    const db = new DatabaseSync(resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT), { readOnly: true });
    const brands = (db.prepare('SELECT DISTINCT brand FROM products').all() as { brand: string }[]).map((r) => r.brand);
    const counts = new Map<string, number>();
    for (const r of db.prepare('SELECT brand, COUNT(*) n FROM products GROUP BY 1').all() as { brand: string; n: number }[]) {
      counts.set(r.brand, r.n);
    }
    db.close();

    const hits = matchBrands(recalls, brands);
    const affected = [...hits.entries()]
      .map(([brand, rs]) => ({ brand, products: counts.get(brand) ?? 0, recalls: rs }))
      .sort((a, b) => b.products - a.products);

    writeFileSync(outPath, JSON.stringify({ fetchedAt: new Date().toISOString(), source: 'fda.gov animal-veterinary recalls-withdrawals', recalls, affected }, null, 2));

    const years = new Set(recalls.map((r) => r.date.slice(-4)));
    console.log('');
    console.log(`recalls collected : ${recalls.length}  (${[...years].sort()[0]}-${[...years].sort().pop()})`);
    console.log(`catalog brands hit: ${affected.length}`);
    console.log(`products affected : ${affected.reduce((n, a) => n + a.products, 0).toLocaleString()}`);
    console.log('');
    for (const a of affected.slice(0, 15)) {
      console.log(`  ${a.brand.padEnd(24)} ${String(a.products).padStart(5)} products  ${a.recalls[0].date}  ${a.recalls[0].reason.slice(0, 52)}`);
    }
    console.log('');
    console.log(`written: ${outPath}`);
    console.log('');
    return;
  }

  if (cmd === 'collect-petco') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const key = firecrawlKey();
    const before = await firecrawlCredits(key);
    process.stderr.write(`firecrawl credits: ${before}\n`);

    let targets = await petcoTargets(key);
    process.stderr.write(`Petco: ${targets.length} product urls discovered\n`);

    const budget = Number(arg(argv, 'budget') ?? '0');
    if (budget && targets.length > budget) {
      process.stderr.write(`budget ${budget}: taking the first ${budget} of ${targets.length}\n`);
      targets = targets.slice(0, budget);
    }

    const r = await harvest({
      name: arg(argv, 'name') ?? 'petco',
      workDir: work,
      targets,
      idOf: (t) => t.id,
      fetchOne: fetchPetco(key),
      concurrency: Number(arg(argv, 'concurrency') ?? '4'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest('Petco (US)', r);
    console.log(`  credits: ${before} -> ${await firecrawlCredits(key)}`);
    console.log('');
    return;
  }

  if (cmd === 'collect-petsathome' || cmd === 'collect-petbarn') {
    const uk = cmd === 'collect-petsathome';
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const key = firecrawlKey();
    const before = await firecrawlCredits(key);
    process.stderr.write(`firecrawl credits: ${before}\n`);

    // Discovery differs by site and neither cost is per-product: Petbarn publishes a sitemap
    // index (free), Pets at Home declares none, so /map runs once per search term.
    let targets = uk ? await petsathomeTargets(key) : await petbarnTargets();
    process.stderr.write(`${uk ? 'Pets at Home' : 'Petbarn'}: ${targets.length} product urls discovered\n`);

    // Every PDP is one credit, so a budget is a hard cap on spend, not a suggestion. Items
    // already in the ledger cost nothing and are not counted against it.
    const budget = Number(arg(argv, 'budget') ?? '0');
    if (budget && targets.length > budget) {
      process.stderr.write(`budget ${budget}: taking the first ${budget} of ${targets.length}\n`);
      targets = targets.slice(0, budget);
    }

    const r = await harvest({
      name: arg(argv, 'name') ?? (uk ? 'petsathome' : 'petbarn'),
      workDir: work,
      targets,
      idOf: (t) => t.id,
      fetchOne: uk ? fetchPetsathome(key) : fetchPetbarn(key),
      concurrency: Number(arg(argv, 'concurrency') ?? '4'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    reportHarvest(uk ? 'Pets at Home (UK)' : 'Petbarn (AU)', r);
    console.log(`  credits: ${before} -> ${await firecrawlCredits(key)}`);
    console.log('');
    return;
  }

  if (cmd === 'ingest') {
    const work = resolve(process.cwd(), arg(argv, 'work') ?? DEFAULT_WORK);
    const names = (arg(argv, 'names') ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const found = names.length
      ? names
      : existsSync(work)
        ? readdirSync(work)
            .filter((f) => f.endsWith('.jsonl'))
            .map((f) => f.replace(/\.jsonl$/, ''))
        : [];
    if (!found.length) {
      console.error(`no harvest files in ${work} — run a collect-* command first`);
      process.exitCode = 2;
      return;
    }
    const r = ingest({
      workDir: work,
      names: found,
      dbPath: resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT),
      dryRun: argv.includes('--dry-run'),
      onLog: (s) => process.stderr.write(s + '\n'),
    });
    console.log('');
    console.log(`harvests          : ${found.join(', ')}`);
    console.log(`records read      : ${r.read.toLocaleString()}`);
    console.log('');
    console.log('Rejected:');
    for (const [reason, n] of Object.entries(r.rejected).sort((a, b) => b[1] - a[1])) {
      if (n) console.log(`  ${reason.padEnd(20)} ${String(n).padStart(7)}  ${pct(n, r.read)}`);
    }
    console.log('');
    console.log(`unique candidates : ${r.candidates.toLocaleString()}`);
    console.log(`already in catalog: ${r.alreadyHeld.toLocaleString()}`);
    console.log(`brand spellings folded: ${r.brandsFolded.toLocaleString()}`);
    console.log(`tier C (too thin) : ${r.tierC.toLocaleString()}  (net-new but not shippable)`);
    console.log(`${argv.includes('--dry-run') ? 'WOULD INSERT' : 'INSERTED    '}      : ${r.inserted.toLocaleString()}`);
    if (r.analysisMigrated) console.log('analysis columns    : added to products');
    if (!argv.includes('--dry-run')) console.log(`macros written    : ${r.analysisWritten.toLocaleString()}  (new + existing rows)`);
    console.log(`  by source       : ${JSON.stringify(r.bySource)}`);
    console.log(`  new brands      : ${r.topNewBrands.map(([b, n]) => `${b}(${n})`).join(', ') || '—'}`);
    console.log('');
    console.log(`catalog           : ${r.countBefore.toLocaleString()} -> ${r.countAfter.toLocaleString()} products`);
    console.log('');
    if (!argv.includes('--dry-run')) {
      console.log('next: npm run petcatalog -- pack');
      console.log('');
      warnIfUngrouped(resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT));
    }
    console.log('');
    return;
  }

  if (cmd === 'clean') {
    const dbPath = resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT);
    const apply = argv.includes('--apply');
    const r = cleanCatalog({ dbPath, apply, onLog: (s) => process.stderr.write(s + '\n') });
    console.log('');
    console.log(`scanned           : ${r.scanned.toLocaleString()} rows`);
    console.log(`repairable rows  : ${r.repaired.toLocaleString()}  (debris re-stripped, kept)`);
    console.log('corrupt rows found:');
    for (const [reason, n] of Object.entries(r.byReason).sort((a, b) => b[1] - a[1])) {
      console.log(`  ${reason.padEnd(24)} ${String(n).padStart(6)}  ${pct(n, r.scanned)}`);
    }
    if (!Object.keys(r.byReason).length) console.log('  none — catalog is clean');
    console.log('');
    for (const s of r.samples) {
      console.log(`  [${s.reason}] ${s.brand.slice(0, 16).padEnd(18)} ${s.name.slice(0, 32).padEnd(34)} ${s.ingredients}`);
    }
    console.log('');
    if (apply) {
      console.log(`REMOVED           : ${r.removed.toLocaleString()}`);
      console.log(`catalog           : ${r.countBefore.toLocaleString()} -> ${r.countAfter.toLocaleString()}`);
      console.log('');
      if (r.orphanedGroups) {
        console.log(`WARNING: ${r.orphanedGroups.toLocaleString()} search groups lost their representative row.`);
        console.log('         Search joins groups to products on that gtin, so those listings —');
        console.log('         and every sibling size in them — are hidden until a regroup.');
        console.log('');
      }
      console.log('next: npm run petcatalog -- pack   (reclaims the freed pages)');
      if (r.orphanedGroups) console.log('      npm run petcatalog -- group --apply   (repairs the orphaned groups)');
    } else {
      console.log('dry run — pass --apply to delete these rows');
    }
    console.log('');
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
    console.log('next: npm run petcatalog -- group --apply' + (r.migrated ? '   (pack rebuilt products, so group_id is gone)' : ''));
    console.log('');
    warnIfUngrouped(db);
    return;
  }

  if (cmd === 'group') {
    // Fold size/pack variants into one search listing. Nothing is deleted — see group.ts.
    const dbPath = resolve(process.cwd(), arg(argv, 'db') ?? DEFAULT_OUT);
    const apply = argv.includes('--apply');
    const r = groupCatalog({ dbPath, apply, onLog: (s) => process.stderr.write(s + '\n') });
    console.log('');
    console.log(`rows              : ${r.rows.toLocaleString()}`);
    console.log(`search listings   : ${r.groups.toLocaleString()}  (${pct(r.absorbed, r.rows)} fewer)`);
    console.log(`groups w/ variants: ${r.multiVariant.toLocaleString()}  (largest ${r.largest})`);
    console.log(`  of those, exact duplicate listings: ${r.exactDuplicates.toLocaleString()}`);
    // The cost side of the trade: search_text is duplicated name/brand text, and this file
    // ships inside the app.
    console.log(`search_text       : ${(r.searchTextBytes / 1e6).toFixed(1)} MB of denormalised name+brand`);
    console.log('');
    for (const s of r.samples) {
      console.log(`  ${s.name.slice(0, 70)}`);
      for (const v of s.variants) console.log(`    - ${v.slice(0, 84)}`);
    }
    console.log('');
    console.log(apply ? 'written — product_groups + products.group_id' : 'dry run — pass --apply to write the groups');
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
