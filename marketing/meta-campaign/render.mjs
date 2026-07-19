/* Render every creative template to PNG at exact Meta sizes using Playwright + system Chromium.
   Usage: npm install && node render.mjs
   Output: output/1x1|4x5|9x16/*.png  and  output/carousel/*.png */

import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { mkdirSync } from 'node:fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const TEMPLATES = resolve(__dirname, 'templates');
const OUT = resolve(__dirname, 'output');

const RATIOS = { '1x1': [1080, 1080], '4x5': [1080, 1350], '9x16': [1080, 1920] };

const STATICS = [
  '01-toxic-reveal',
  '02-instant-demo',
  '03-vet-science',
  '04-allergen',
  '05-ultra-processed',
];
const CAROUSEL = ['card-1', 'card-2', 'card-3', 'card-4', 'card-5'];

// Prefer the pre-installed system Chromium; fall back to Playwright's own resolution.
const EXECUTABLE = process.env.PW_CHROMIUM || '/opt/pw-browsers/chromium';

async function shoot(page, url, [w, h], outPath) {
  await page.setViewportSize({ width: w, height: h });
  await page.goto(url, { waitUntil: 'load' });
  await page.evaluate(() => (document.fonts ? document.fonts.ready : true));
  await page.waitForTimeout(150); // let paw injection + layout settle
  const el = page.locator('.creative');
  await el.screenshot({ path: outPath });
  console.log('✓', outPath.replace(OUT + '/', 'output/'));
}

const launchOpts = { headless: true };
try { launchOpts.executablePath = EXECUTABLE; } catch { /* use default */ }

const browser = await chromium.launch(launchOpts);
const page = await browser.newPage({ deviceScaleFactor: 1 });

let count = 0;
// Statics — every ratio.
for (const name of STATICS) {
  for (const [ratio, dims] of Object.entries(RATIOS)) {
    const dir = resolve(OUT, ratio);
    mkdirSync(dir, { recursive: true });
    const url = 'file://' + resolve(TEMPLATES, name + '.html') + '?r=' + ratio;
    await shoot(page, url, dims, resolve(dir, name + '.png'));
    count++;
  }
}
// Carousel — 1:1 only.
const cdir = resolve(OUT, 'carousel');
mkdirSync(cdir, { recursive: true });
for (const card of CAROUSEL) {
  const url = 'file://' + resolve(TEMPLATES, 'carousel', card + '.html') + '?r=1x1';
  await shoot(page, url, RATIOS['1x1'], resolve(cdir, card + '.png'));
  count++;
}

await browser.close();
console.log('\nDone — ' + count + ' creatives rendered.');
