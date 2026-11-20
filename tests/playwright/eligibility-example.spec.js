const { test, expect } = require('@playwright/test');
const path = require('path');

// Eligibility example pages rendered by render-kri-example-fixture.R. A failed
// render only drops the page from the site menu, so these also check that both
// pages render.
const PAGES = {
  basic: { file: 'Example_Eligibility.html', other: 'Example_Eligibility_Pilot.html', label: 'Basic' },
  pilot: { file: 'Example_Eligibility_Pilot.html', other: 'Example_Eligibility.html', label: 'Pilot data' },
};

for (const [mode, { file, other, label }] of Object.entries(PAGES)) {
  test.describe(`${mode} eligibility example`, () => {
    let errors;

    test.beforeEach(async ({ page }) => {
      errors = [];
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.goto('file://' + path.resolve(__dirname, 'fixture', file));
      await page.waitForFunction(() => window.Reactable && document.getElementById('elig-site-status')?.gsmChart, null, { timeout: 30000 });
    });

    test(`marks ${label} as the current view and links to the other mode (#371)`, async ({ page }) => {
      const current = page.locator('.elig-view-switch [aria-current="page"]');
      await expect(current).toHaveText(label);
      await expect(page.locator('.elig-view-switch a')).toHaveAttribute('href', other);
      expect(errors).toEqual([]);
    });

    test(`renders the ${mode} mode report (#371)`, async ({ page }) => {
      const labels = await page.evaluate(() => document.getElementById('elig-site-status').gsmChart.data.datasets.map((d) => d.label));
      expect(await page.locator('#deep-dive-listing').count()).toBe(0);
      if (mode === 'basic') {
        expect(labels).not.toContain('Potentially Ineligible');
      } else {
        expect(labels).toContain('Potentially Ineligible');
        await expect(page.locator('#status-over-time')).toHaveCount(1);
      }
    });

    test(`${mode} PD records are one per PD (#371)`, async ({ page }) => {
      const pd = await page.evaluate(() => JSON.parse(document.getElementById('elig-data').textContent)
        .export.rows.map((r) => r['Protocol Deviation details']));
      expect(pd.filter((d) => d.includes(';;;'))).toEqual([]);
      expect(pd.some((d) => d.includes(' | ID: PD-') || d.includes(' | Date: '))).toBe(true);
    });
  });
}
