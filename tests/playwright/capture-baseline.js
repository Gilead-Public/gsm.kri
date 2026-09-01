// Renders each fixture in headless Chromium, captures the structural fingerprint
// + a full-page screenshot, and (when OUT is unset) writes baseline.json.
//   node tests/playwright/capture-baseline.js            # writes baseline.json + *.baseline.png
//   OUT=after node tests/playwright/capture-baseline.js  # writes *.after.png for comparison
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { FIXTURES, fixtureUrl, readFingerprint } = require('./fingerprint');

(async () => {
  const label = process.env.OUT || 'baseline';
  const artifacts = path.resolve(__dirname, 'artifacts');
  fs.mkdirSync(artifacts, { recursive: true });
  const browser = await chromium.launch();
  const out = {};
  for (const [name, file] of Object.entries(FIXTURES)) {
    const page = await browser.newPage();
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', (e) => errors.push(String(e)));
    await page.goto(fixtureUrl(file));
    await page.waitForTimeout(1500); // let Chart.js canvases paint
    out[name] = await readFingerprint(page);
    out[name].consoleErrors = errors.length;
    await page.screenshot({ path: path.join(artifacts, `${name}.${label}.png`), fullPage: true });
    await page.close();
  }
  await browser.close();
  if (label === 'baseline') {
    fs.writeFileSync(path.join(__dirname, 'baseline.json'), JSON.stringify(out, null, 2) + '\n');
    console.log('Wrote baseline.json:\n' + JSON.stringify(out, null, 2));
  } else {
    console.log(`Captured ${label}:\n` + JSON.stringify(out, null, 2));
  }
})();
