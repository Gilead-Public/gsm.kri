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

test('native percent (fill) mode survives a country filter (#264)', async ({ page }) => {
  // The native fill button issues updateSpec({position:'stack', stat:'percent'});
  // the country->site narrow re-applies the LIVE _spec_ via helpers.updateData,
  // so percent must persist. Guards the report's updateData path, not gsm.viz.
  const siteStat = () => page.evaluate(() =>
    document.querySelector('#pd-site-buckets').gsmChart.data._spec_.stat);
  await page.evaluate(() => {
    const c = document.querySelector('#pd-site-buckets').gsmChart;
    c.helpers.updateSpec(c, { position: 'stack', stat: 'percent' });
  });
  await expect.poll(siteStat).toBe('percent');
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  expect(await siteStat()).toBe('percent');   // persisted across the updateData narrow
});

test('the custom sticky toggle is gone; buckets keep the gsm.viz native control (#264)', async ({ page }) => {
  expect(await page.locator('#pd-mode-toggle').count()).toBe(0);   // custom sticky removed
  const enabled = await page.evaluate(() => {
    const s = document.querySelector('#pd-study-buckets').gsmChart.data._spec_;
    return !!(s.mapping && s.mapping.fill) && s.interactive !== false;
  });
  expect(enabled).toBe(true);   // native positionToggle (stack/dodge/fill) will render
});
