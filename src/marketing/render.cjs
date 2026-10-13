#!/usr/bin/env node
// Rend les visuels de HydroBar à partir de template.html.
//
//   node src/marketing/render.cjs             → captures App Store, 9 langues
//   node src/marketing/render.cjs --readme    → images du README (anglais)
//   node src/marketing/render.cjs --only fr-FR → une seule langue
//
// Les captures App Store vont dans src/fastlane/screenshots/<langue>/, au format
// 2880 × 1800 accepté par App Store Connect.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const { LOCALES } = require('./strings.cjs');
const { SCREENS, build } = require('./data.cjs');

// Le dossier src/ (captures de la fiche) et la racine du dépôt (images du README).
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..');
const TEMPLATE = 'file://' + path.join(__dirname, 'template.html');
const args = process.argv.slice(2);
const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null;

async function launch() {
  // Chromium préinstallé (CI, conteneurs), sinon celui de Playwright.
  const executablePath = ['/opt/pw-browsers/chromium'].find((p) => fs.existsSync(p));
  return chromium.launch(executablePath ? { executablePath } : {});
}

async function shoot(browser, data, file, { width = 1440, height = 900, clip, scale = 2 } = {}) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: scale, colorScheme: 'dark' });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript((d) => { window.__DATA = d; }, data);
  await page.goto(TEMPLATE, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  if (errors.length) throw new Error(`${file} : ${errors.join(', ')}`);
  // Un texte qui déborde de son cadre se voit à peine en miniature : on le refuse.
  const overflow = await page.evaluate(() => [...document.querySelectorAll('.copy h1, .copy p, .tab span, .preset, .hold, .menu .item, .mark')]
    .filter((el) => el.scrollWidth > el.clientWidth + 1).map((el) => el.textContent));
  if (overflow.length) console.warn(`  ⚠ ${path.basename(file)} : texte trop long → ${overflow.join(' | ')}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  // JPEG : accepté par App Store Connect, et dix fois plus léger qu'un PNG ici.
  const jpeg = file.endsWith('.jpg');
  await page.screenshot({ path: file, clip, ...(jpeg ? { type: 'jpeg', quality: 90 } : {}) });
  await page.close();
}

(async () => {
  const browser = await launch();
  if (args.includes('--readme')) {
    const out = path.join(REPO, 'Resources/v2');
    for (const screen of SCREENS) {
      await shoot(browser, { ...build('en-US', screen), bare: true }, path.join(out, `${screen}.jpg`),
        { clip: { x: 0, y: 0, width: 800, height: 756 }, scale: 1.5 });
      console.log(`✓ Resources/v2/${screen}.jpg`);
    }
    // Bannière du README et aperçu social GitHub (1280 × 640).
    const hero = (width, height, desk, zoom) => ({
      ...build('en-US', 'today'),
      caption: ['HydroBar', 'Hydration in your menu bar. Native, private, and out of your way.'],
      hero: { width, height, desk, zoom, badges: ['macOS 15+', '9 languages', 'No account', 'No tracking'] },
    });
    await shoot(browser, hero(1600, 800, { width: 640, height: 720, top: 40, right: 56 }, 1.15),
      path.join(out, 'hero.jpg'), { width: 1600, height: 800, scale: 1.5 });
    console.log('✓ Resources/v2/hero.jpg');
    await shoot(browser, hero(1280, 640, { width: 520, height: 600, top: 20, right: 40 }, 0.95),
      path.join(out, 'social-preview.jpg'), { width: 1280, height: 640, scale: 1 });
    console.log('✓ Resources/v2/social-preview.jpg');
  } else {
    for (const locale of Object.keys(LOCALES)) {
      if (only && locale !== only) continue;
      for (const [index, screen] of SCREENS.entries()) {
        const file = path.join(ROOT, 'fastlane/screenshots', locale, `${index + 1}_${screen}.jpg`);
        await shoot(browser, build(locale, screen), file);
      }
      console.log(`✓ ${locale} : ${SCREENS.length} captures`);
    }
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
