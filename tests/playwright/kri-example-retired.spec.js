const { test, expect } = require('@playwright/test');
const path = require('path');

// Example pages rendered by render-kri-example-fixture.R. Each adds a retired
// metric copied from the Adverse Event Rate: inactive, with results in earlier
// snapshots only.
const PAGES = {
  Site: { file: 'Example_SiteReport.html', retired: 'Analysis_kri9999', source: 'Analysis_kri0001' },
  Country: { file: 'Example_CountryReport.html', retired: 'Analysis_cou9999', source: 'Analysis_cou0001' },
};

// Snapshot dates on the x-axis of a metric's time series.
const snapshots = (page, id) =>
  page.locator(`#results .gsm-widget.${id}.timeSeries canvas`).evaluate((c) => c.chart.data.labels);

for (const [level, { file, retired, source }] of Object.entries(PAGES)) {
  test.describe(`${level} example page`, () => {
    let errors;

    test.beforeEach(async ({ page }) => {
      errors = [];
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.goto('file://' + path.resolve(__dirname, 'fixture', file));
      // The floating table of contents is built client-side after load.
      await page.waitForSelector('#TOC li', { state: 'attached' });
    });

    test('loads with zero console/page errors', () => {
      expect(errors).toEqual([]);
    });

    test('retired metric is listed last in Results with an Inactive badge', async ({ page }) => {
      const header = page.locator('#results h3').last();
      // firstChild is the header's own text, without the badge.
      expect(await header.evaluate((el) => el.firstChild.textContent.trim())).toBe('Retired Metric');
      await expect(header.locator('.metric-inactive')).toHaveText('Inactive');
    });

    test('retired metric shows only a time series, without the latest snapshot', async ({ page }) => {
      const widgets = page.locator(`#results .gsm-widget.${retired}`);
      await expect(widgets).toHaveCount(1);
      await expect(widgets).toHaveClass(/timeSeries/);
      await expect(widgets.locator('canvas')).toBeVisible();

      const all = await snapshots(page, source);
      expect(all.length).toBeGreaterThan(1);
      expect(await snapshots(page, retired)).toEqual(all.slice(0, -1));
    });

    test('every other metric keeps its four charts', async ({ page }) => {
      const counts = await page.locator('#results .gsm-widget').evaluateAll((els) => {
        const n = {};
        for (const el of els) {
          const id = Array.from(el.classList).find((c) => c.startsWith('Analysis_'));
          n[id] = (n[id] || 0) + 1;
        }
        return n;
      });
      delete counts[retired];
      expect(Object.keys(counts).length).toBeGreaterThan(0);
      expect(new Set(Object.values(counts))).toEqual(new Set([4]));
    });
  });
}
