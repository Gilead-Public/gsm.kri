const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { FIXTURES, fixtureUrl, readFingerprint, structural } = require('./fingerprint');

const baseline = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'baseline.json'), 'utf8'));

for (const [name, file] of Object.entries(FIXTURES)) {
  test.describe(`${name} report on the gsm.vizr-served gsm.viz bundle`, () => {
    let errors;
    test.beforeEach(async ({ page }) => {
      errors = [];
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.goto(fixtureUrl(file));
      await page.waitForTimeout(1500); // let Chart.js canvases paint
    });

    // A re-based widget whose gsm.viz entrypoint drifted throws during
    // renderValue() -> a console/page error. This is the highest-signal,
    // lowest-code catch for API breakage across the bundle bump.
    test('loads with zero console/page errors', () => {
      expect(errors, `bundle threw while initialising a widget:\n${errors.join('\n')}`).toEqual([]);
    });

    test('structural fingerprint matches the committed 2.3.0 baseline', async ({ page }) => {
      const live = await readFingerprint(page);
      expect(live).toEqual(structural(baseline[name]));
    });

    test('at least one chart canvas is visibly drawn', async ({ page }) => {
      const drawn = await page.evaluate(() =>
        Array.from(document.querySelectorAll('.html-widget canvas')).some((c) => {
          const b = c.getBoundingClientRect();
          return b.width > 1 && b.height > 1;
        })
      );
      expect(drawn).toBe(true);
    });
  });
}
