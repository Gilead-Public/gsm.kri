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

test('faceted site widget renders per-panel charts with selectCategory (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas', { timeout: 20000 });
  const ok = await page.evaluate(() => {
    const el = document.querySelector('#pd-site-buckets');
    const r = el.gsmChart;
    return !!(r && Array.isArray(r.charts) && r.charts.length >= 1 &&
      typeof r.charts[0].helpers.selectCategory === 'function');
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

test('clicking a faceted site bar dispatches pdBucketClick (level=site) (#264)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas');
  await page.evaluate(() => {
    window.__pd = null;
    document.addEventListener('pdBucketClick', (e) => { window.__pd = e.detail; });
  });
  // Facet sub-charts are small, so target the exact center of the first
  // non-empty bar segment (from chart metadata) rather than a guessed pixel.
  const pt = await page.evaluate(() => {
    const chart = document.querySelector('#pd-site-buckets').gsmChart.charts[0];
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
});
