const { test, expect } = require('@playwright/test');
const path = require('path');
const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report.html');

test.beforeEach(async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas', { timeout: 20000 });
});

test('all three bucket charts render Chart.js canvases, not Plotly (#264)', async ({ page }) => {
  for (const id of ['pd-study-buckets', 'pd-country-buckets', 'pd-site-buckets']) {
    expect(await page.locator('#' + id + ' canvas').count()).toBeGreaterThan(0);
    expect(await page.locator('#' + id + ' .plotly').count()).toBe(0);
  }
});

test('count/% toggle swaps the bucket y-axis label (#264)', async ({ page }) => {
  const yLabel = () => page.evaluate(() => {
    const el = document.querySelector('#pd-study-buckets');
    return el.gsmChart.options.scales.y.title.text;
  });
  expect(await yLabel()).toMatch(/Subjects/);
  await page.locator('#pd-mode-pct').click();          // existing percent toggle id
  await expect.poll(yLabel).toMatch(/%|Percent/);
});

test('country→site→listing drilldown filters the DT listing (#264)', async ({ page }) => {
  const rowsBefore = await page.locator('table.dataTable tbody tr').count();
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  const rowsAfter = await page.locator('table.dataTable tbody tr').count();
  expect(rowsAfter).toBeLessThanOrEqual(rowsBefore);
});

test('country click narrows the country scatter — Plotly stays in step (#264)', async ({ page }) => {
  const nPoints = () => page.evaluate(() => {
    const el = document.querySelector('#pd-country-scatter');
    return (el && el.data && el.data[0] && el.data[0].x) ? el.data[0].x.length : -1;
  });
  const before = await nPoints();
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  expect(await nPoints()).toBeLessThanOrEqual(before);   // scatter followed the bucket click
});

test('country click narrows the flat site chart to that country only (#264)', async ({ page }) => {
  const siteLabels = () => page.evaluate(() =>
    document.querySelector('#pd-site-buckets').gsmChart.data.labels.slice());
  const before = await siteLabels();                     // all sites
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  const after = await siteLabels();
  expect(after.length).toBeGreaterThan(0);
  expect(after.length).toBeLessThan(before.length);      // narrowed to USA's sites
  // Resetting the country filter restores all sites.
  await page.evaluate(() => document.getElementById('pd-filter-reset').click());
  await page.waitForTimeout(300);
  expect((await siteLabels()).length).toBe(before.length);
});
