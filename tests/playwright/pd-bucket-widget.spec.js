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
    // Flat bars (a single Chart.js instance, not a facet {charts}). The
    // report's country->site drilldown re-slices from its own inlined
    // pdSiteRows JSON now (#288, el.pdAllData is gone), but the ORIGINAL rows
    // still live on the rendered chart -- Chart.js keeps the source row on
    // each point as `_datum` (see pd-buckets.spec.js's readLabel).
    const rows = c.data.datasets.flatMap((d) => d.data).filter(Boolean).map((p) => p._datum);
    return !!(c && !Array.isArray(c.charts) &&
      typeof c.helpers.selectCategory === 'function' &&
      typeof c.helpers.updateData === 'function' &&
      rows.length > 0 &&
      rows.every((r) => 'OuterGroupID' in r));
  });
  expect(ok).toBe(true);
});

test('gsmViz loads exactly once, resolved from gsm.vizr, with main.css present (#288)', async ({ page }) => {
  // Guards against the exact regression a stale/duplicate dependency copy
  // would cause (two conflicting gsmViz builds, or main.css missing): the
  // harness fixture is not self-contained, so the widget's htmlDependency
  // resolves to real, individually-observable network requests -- the
  // self-contained Report.html fixture inlines everything as base64 and
  // cannot make this assertion.
  const requests = [];
  page.on('request', (req) => requests.push(req.url()));
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-study-buckets canvas', { timeout: 20000 });

  const indexJs = requests.filter((u) => /\/gsmViz-[\d.]+\/index\.js$/.test(u));
  expect(indexJs).toHaveLength(1);
  const mainCss = requests.filter((u) => /\/gsmViz-[\d.]+\/main\.css$/.test(u));
  expect(mainCss).toHaveLength(1);
  // No leftover copy of the deleted package-local widget bindings loads
  // alongside it (the thing that would make "exactly one" not enough).
  expect(requests.some((u) => /Widget_PrematureDeath/.test(u))).toBe(false);
});

test('clicking a study bar dispatches gsm-viz-select with a datum payload (#288)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#pd-study-buckets canvas');
  await page.evaluate(() => {
    window.__pd = null;
    document.addEventListener('gsm-viz-select', (e) => { window.__pd = e.detail; });
  });
  const box = await page.locator('#pd-study-buckets canvas').boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  const detail = await page.evaluate(() => window.__pd);
  expect(detail).not.toBeNull();
  expect(detail).toMatchObject({ type: 'click', chartId: 'pd-study-buckets' });
  expect(detail.metadata).toMatchObject({ level: 'study' });
  expect(detail.datum).toBeTruthy();
});

test('clicking a site bar dispatches gsm-viz-select (level=site) with its country in the datum (#288)', async ({ page }) => {
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
    document.addEventListener('gsm-viz-select', (e) => { window.__pd = e.detail; });
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
  expect(detail.metadata).toMatchObject({ level: 'site' });
  // Raw wrapper contract: the widget forwards the clicked row's OuterGroupID
  // (the site's country) unchanged -- deriving `country`/`invid` off it is the
  // REPORT's job (filter-js), not the widget's; see pd-buckets.spec.js.
  expect(detail.datum.OuterGroupID).toBeTruthy();
});
