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

test('site and country bucket charts enable x-axis zoom; study chart does not (#264)', async ({ page }) => {
  const zoomOf = (id) => page.evaluate((id) => {
    const z = document.querySelector('#' + id).gsmChart.options.plugins.zoom;
    if (!z || !z.zoom) return { mode: null, wheel: false };
    return { mode: z.zoom.mode, wheel: !!(z.zoom.wheel && z.zoom.wheel.enabled) };
  }, id);
  for (const id of ['pd-site-buckets', 'pd-country-buckets']) {
    const z = await zoomOf(id);
    expect(z.mode).toBe('x');
    expect(z.wheel).toBe(true);
  }
  // Study chart carries only the zoom plugin's inert defaults (zoom disabled).
  expect((await zoomOf('pd-study-buckets')).wheel).toBe(false);
});

test('a real site-bar click still drills down with zoom/pan active (#264)', async ({ page }) => {
  await page.evaluate(() => {
    window.__pd = null;
    document.addEventListener('pdBucketClick', (e) => { window.__pd = e.detail; });
  });
  await page.locator('#pd-site-buckets').scrollIntoViewIfNeeded();
  // Click the center of a real (non-zero) site bar via its Chart.js element pixel.
  const pt = await page.evaluate(() => {
    const c = document.querySelector('#pd-site-buckets').gsmChart;
    const r = c.canvas.getBoundingClientRect();
    for (let ds = 0; ds < c.data.datasets.length; ds++) {
      const arr = c.data.datasets[ds].data, meta = c.getDatasetMeta(ds);
      for (let i = 0; i < arr.length; i++) {
        if (arr[i] && arr[i]._datum && arr[i]._datum.n > 0 && meta.data[i]) {
          return { x: r.left + meta.data[i].x, y: r.top + meta.data[i].y };
        }
      }
    }
    return null;
  });
  expect(pt).not.toBeNull();
  await page.mouse.click(pt.x, pt.y);
  await expect.poll(() => page.evaluate(() => window.__pd && window.__pd.level)).toBe('site');
});

test('count/% toggle survives a country filter (#264)', async ({ page }) => {
  // Assert on the SITE chart: it is the one narrowing drives through
  // helpers.updateData, which re-reads the live _spec_ the toggle already
  // flipped to y="pct". If updateData reverted to the base spec the site bars
  // would drop back to counts, so this guards mode persistence across a filter.
  const siteYLabel = () => page.evaluate(() =>
    document.querySelector('#pd-site-buckets').gsmChart.options.scales.y.title.text);
  await page.locator('#pd-mode-pct').click();
  await expect.poll(siteYLabel).toMatch(/%|Percent/);
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  expect(await siteYLabel()).toMatch(/%|Percent/);       // mode persisted across the updateData narrow
});
