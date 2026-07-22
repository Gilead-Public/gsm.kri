const { test, expect } = require('@playwright/test');
const path = require('path');
const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'pd-bucket-harness.html');

test('study widget renders a canvas and exposes all load-bearing helpers (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-study-buckets canvas', { timeout: 20000 });
  const ok = await page.evaluate(() => {
    const el = document.querySelector('#pd-study-buckets');
    const h = el.gsmChart && el.gsmChart.helpers;
    // De-risk EVERY helper the migration depends on, not just the two below:
    // updateSpec (toggle), selectCategory + clearSelection (highlight, Task 5),
    // updateData (country-reactive reason swap, Tasks 8/9).
    return !!(h &&
      typeof h.updateSpec === 'function' &&
      typeof h.selectCategory === 'function' &&
      typeof h.clearSelection === 'function' &&
      typeof h.updateData === 'function');
  });
  expect(ok).toBe(true);
});

test('site widget renders a flat canvas, exposes helpers + keeps original rows (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas', { timeout: 20000 });
  const ok = await page.evaluate(() => {
    const el = document.querySelector('#pd-site-buckets');
    const c = el.gsmChart;
    // Flat bars (a single Chart.js instance, not a facet {charts}), plus the
    // pdAllData rows the report re-slices for the country->site drilldown.
    return !!(c && !Array.isArray(c.charts) &&
      typeof c.helpers.selectCategory === 'function' &&
      typeof c.helpers.updateData === 'function' &&
      Array.isArray(el.pdAllData) && el.pdAllData.length > 0 &&
      'OuterGroupID' in el.pdAllData[0]);
  });
  expect(ok).toBe(true);
});

test('clicking a study bar dispatches pdBucketClick with a datum payload (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-study-buckets canvas');
  await page.evaluate(() => {
    window.__pd = null;
    document.addEventListener('pdBucketClick', (e) => { window.__pd = e.detail; });
  });
  const box = await page.locator('#pd-study-buckets canvas').boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  const detail = await page.evaluate(() => window.__pd);
  expect(detail).not.toBeNull();
  expect(detail).toHaveProperty('level', 'study');
});

test('clicking a site bar dispatches pdBucketClick (level=site) with its country (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas');
  // The site chart sits below the study chart; scroll it into view so the raw
  // mouse.click below lands on a bar rather than off-screen. Settle first: the
  // study chart above can still be sizing, which shifts this chart's position
  // between the coordinate read and the click.
  await page.locator('#pd-site-buckets').scrollIntoViewIfNeeded();
  await page.waitForTimeout(300);
  await page.evaluate(() => {
    window.__pd = null;
    document.addEventListener('pdBucketClick', (e) => { window.__pd = e.detail; });
  });
  // Target the exact center of the first non-empty bar segment (from metadata).
  const pt = await page.evaluate(() => {
    const chart = document.querySelector('#pd-site-buckets').gsmChart;
    const rect = chart.canvas.getBoundingClientRect();
    for (let ds = 0; ds < chart.data.datasets.length; ds++) {
      const bar = chart.getDatasetMeta(ds).data.find((b) => Math.abs(b.base - b.y) > 1);
      if (bar) return { x: rect.x + bar.x, y: rect.y + (bar.y + bar.base) / 2 };
    }
    return null;
  });
  expect(pt).not.toBeNull();
  await page.mouse.click(pt.x, pt.y);
  const detail = await page.evaluate(() => window.__pd);
  expect(detail).not.toBeNull();
  expect(detail).toHaveProperty('level', 'site');
  // Site clicks carry the site's country (from OuterGroupID) for the drilldown.
  expect(detail.country).toBeTruthy();
});
