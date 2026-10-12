const { test, expect } = require('@playwright/test');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report_KRI_Inactive.html');

// The fixture (render-kri-inactive-fixture.R) flags kri0007 inactive; the
// other three metrics keep their bundled order.
const ACTIVE = ['Adverse Event Rate', 'Study Discontinuation Rate', 'Query Rate'];
const INACTIVE = 'Treatment Discontinuation Rate';

test.beforeEach(async ({ page }) => {
  await page.goto(fileUrl);
  // The floating table of contents is built client-side after load.
  await page.waitForSelector('#TOC li', { state: 'attached' });
});

test('every metric gets a Results section with charts', async ({ page }) => {
  await expect(page.locator('#results h3')).toHaveCount(4);
  for (const id of ['kri0001', 'kri0006', 'kri0007', 'kri0008']) {
    expect(await page.locator(`#results .gsm-widget.Analysis_${id}`).count()).toBeGreaterThan(0);
  }
});

test('inactive metric is listed last in Results with an Inactive badge', async ({ page }) => {
  const headers = page.locator('#results h3');
  // firstChild is the header's own text, without the badge.
  const names = await headers.evaluateAll((els) => els.map((el) => el.firstChild.textContent.trim()));
  expect(names).toEqual([...ACTIVE, INACTIVE]);
  const badge = headers.last().locator('.metric-inactive');
  await expect(badge).toHaveText('Inactive');
  // Light red with dark red text, so the badge stands out from the header.
  await expect(badge).toHaveCSS('background-color', 'rgb(248, 215, 218)');
  await expect(badge).toHaveCSS('color', 'rgb(132, 32, 41)');
  await expect(page.locator('#results .metric-inactive')).toHaveCount(1);
});

test('table of contents shows the badge on the inactive metric only', async ({ page }) => {
  const entries = await page
    .locator('#TOC li:has(.metric-inactive)')
    .evaluateAll((els) => els.map((el) => el.firstChild.textContent.trim()));
  expect(entries.length).toBeGreaterThan(0);
  expect(new Set(entries)).toEqual(new Set([INACTIVE]));
});

test('overview table lists the inactive metric as the last column', async ({ page }) => {
  const columns = await page.locator('table.group-overview').first().locator('thead th').allInnerTexts();
  expect(columns.map((c) => c.trim()).slice(-4)).toEqual(['AE', 'SDSC', 'QRY', 'TDSC']);
});
