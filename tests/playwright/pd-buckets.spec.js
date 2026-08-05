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

// Chart.js draws labels to canvas, so there is no DOM text to query. Resolve the
// label the way the plugin does instead: call the formatter with a real context.
// Read the RAW config -- chart.options.plugins.datalabels proxies scriptable
// options and would invoke the formatter with a contextless object.
function readLabel(page, id) {
  return page.evaluate((id) => {
    const c = document.querySelector('#' + id).gsmChart;
    const seg = c.config.options.plugins.datalabels.labels.segment;
    let best = null;
    for (let d = 0; d < c.data.datasets.length; d++) {
      const dataset = c.data.datasets[d];
      for (let i = 0; i < dataset.data.length; i++) {
        const p = dataset.data[i];
        if (!p || !p._datum || !(p._datum.n > 0)) continue;
        if (best && p._datum.n <= best.n) continue;
        const ctx = { chart: c, dataset, datasetIndex: d, dataIndex: i };
        best = { text: seg.formatter(p, ctx), shown: seg.display(ctx),
                 n: p._datum.n, pct: p._datum.pct };
      }
    }
    return best;
  }, id);
}

test('bucket segments carry counts that become percentages in fill mode (#264)', async ({ page }) => {
  const counts = await readLabel(page, 'pd-study-buckets');
  expect(counts).not.toBeNull();
  expect(counts.text).toBe(String(counts.n));   // stack mode: raw count
  expect(counts.shown).toBe(true);              // largest segment clears the 16px floor

  // The native fill button issues exactly this update.
  await page.evaluate(() => {
    const c = document.querySelector('#pd-study-buckets').gsmChart;
    c.helpers.updateSpec(c, { position: 'stack', stat: 'percent' });
  });
  const pct = await readLabel(page, 'pd-study-buckets');
  // Shape and value, not an exact string: R serializes pct at 4 dp while
  // gsm.viz recomputes the within-group share at full precision, so an exact
  // compare can straddle a one-decimal rounding boundary.
  expect(pct.text).toMatch(/^\d+\.\d%$/);
  expect(parseFloat(pct.text)).toBeCloseTo(pct.pct, 1);

  // Returning to counts restores the raw value.
  await page.evaluate(() => {
    const c = document.querySelector('#pd-study-buckets').gsmChart;
    c.helpers.updateSpec(c, { position: 'stack', stat: 'count' });
  });
  expect((await readLabel(page, 'pd-study-buckets')).text).toBe(String(counts.n));
});

test('site labels survive the country to site narrow (#264)', async ({ page }) => {
  expect(await readLabel(page, 'pd-site-buckets')).not.toBeNull();
  await page.evaluate(() => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: 'USA', country: 'USA' } })));
  await page.waitForTimeout(300);
  // helpers.updateData re-runs getPlugins, so the label config is rebuilt.
  const after = await readLabel(page, 'pd-site-buckets');
  expect(after).not.toBeNull();
  expect(after.text).toBe(String(after.n));
});

test('a bar too thin to hold its label drops it (#264)', async ({ page }) => {
  // The fixture's two sites are wide, so their labels draw.
  const wide = await readLabel(page, 'pd-site-buckets');
  expect(wide.text).toBe(String(wide.n));

  // Densify to the shape of a real study. gsm.viz's own minSize floor measures
  // the VALUE axis, so these bars stay tall and clear it -- only a category-axis
  // check can drop them. Going through updateData also proves the fit check
  // survives the config rebuild, since a lost check would redraw the labels.
  await page.evaluate(() => {
    const el = document.querySelector('#pd-site-buckets');
    // A non-zero row, so the bar runs the full height of the plot and clears
    // the value-axis floor; a two-digit count is wider than the ~7px bar.
    const proto = el.pdAllData.find((r) => r.n > 0);
    const rows = Array.from({ length: 80 }, (_, i) =>
      Object.assign({}, proto, { GroupID: 'SITE-' + i, n: 10 }));
    el.gsmChart.helpers.updateData(el.gsmChart, rows, el.gsmChart.data._spec_);
  });
  await page.waitForTimeout(400);

  const thin = await page.evaluate(() => {
    const c = document.querySelector('#pd-site-buckets').gsmChart;
    const seg = c.config.options.plugins.datalabels.labels.segment;
    const dataset = c.data.datasets[0];
    const meta = c.getDatasetMeta(0);
    const ctx = { chart: c, dataset, datasetIndex: 0, dataIndex: 0 };
    return {
      // gsm.viz still RESOLVES the text; the category-axis check gates whether
      // it is drawn, so the evidence is display(), not a blanked formatter.
      text: seg.formatter(dataset.data[0], ctx),
      shown: seg.display(ctx),
      barW: meta.data[0].width,
      barH: meta.data[0].height
    };
  });
  expect(thin.barW).toBeLessThan(16);          // far too thin for a digit
  expect(thin.barH).toBeGreaterThanOrEqual(16); // the value-axis floor (minSize) lets it through
  expect(thin.text).toBe('10');                // the label still resolves...
  expect(thin.shown).toBe(false);              // ...the category-axis check drops it
});

test('the zoomable bucket charts caption scroll-to-zoom (#264)', async ({ page }) => {
  // gsm.viz renders labels.captions through Chart.js's subtitle plugin.
  const subtitle = (id) => page.evaluate((id) => {
    const s = document.querySelector('#' + id).gsmChart.config.options.plugins.subtitle;
    return { display: s.display, text: s.text };
  }, id);

  for (const id of ['pd-country-buckets', 'pd-site-buckets']) {
    expect(await subtitle(id)).toEqual({
      display: true,
      text: ['Scroll to zoom in; drag to pan.']
    });
  }
  // The study chart is one bar with no zoom, so it must not advertise it.
  expect((await subtitle('pd-study-buckets')).display).toBe(false);
});

// Helpers shared by the two toggle tests below. Filter state is driven through
// the pdBucketClick CustomEvent rather than a canvas click: the event is the
// widget's public contract with the report, and a synthetic click would depend
// on bar geometry that zoom/pan can move.
const clickBucket = (page, chartId, detail) => page.evaluate(([chartId, detail]) =>
  document.querySelector('#' + chartId)
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true, detail })),
  [chartId, detail]);

// Named siteChartLabels, not siteLabels: an existing test in this file already
// declares a no-arg siteLabels inside its own scope.
const siteChartLabels = (page) => page.evaluate(() =>
  document.querySelector('#pd-site-buckets').gsmChart.data.labels.slice());

// The chips carry an inline display style; the banner gets one from
// updateBannerVisibility() on the first state change.
const shown = (page, id) => page.evaluate((id) =>
  document.getElementById(id).style.display !== 'none', id);

test('re-clicking the active country bar clears the whole drilldown (#264)', async ({ page }) => {
  const usa = { level: 'country', groupId: 'USA', country: 'USA' };
  const allSites = await siteChartLabels(page);

  await clickBucket(page, 'pd-country-buckets', usa);
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(true);
  expect((await siteChartLabels(page)).length).toBeLessThan(allSites.length);

  await clickBucket(page, 'pd-country-buckets', usa);   // same bar again
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(false);
  expect(await shown(page, 'pd-filter-banner')).toBe(false);
  expect(await siteChartLabels(page)).toEqual(allSites);     // site chart un-narrowed
});

test('re-clicking the active site bar clears the site but keeps its country (#264)', async ({ page }) => {
  const inv1 = { level: 'site', groupId: 'INV-1', invid: 'INV-1', country: 'USA' };
  const allSites = await siteChartLabels(page);

  // A site click adopts the site's country, so both chips light up.
  await clickBucket(page, 'pd-site-buckets', inv1);
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-site-chip')).toBe(true);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(true);

  await clickBucket(page, 'pd-site-buckets', inv1);     // same bar again
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-site-chip')).toBe(false);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(true);   // parent survives
  expect((await siteChartLabels(page)).length).toBeLessThan(allSites.length);
});

test('the site bucket tooltip names the parent country; study and country do not (#264)', async ({ page }) => {
  // Chart.js draws tooltips on the canvas, so there is no DOM to assert on:
  // invoke the label callback directly, the same way pd-reasons.spec.js does.
  const label = (id) => page.evaluate((id) => {
    const chart = document.querySelector('#' + id).gsmChart;
    const fn = chart.options.plugins.tooltip.callbacks.label;
    return fn({ dataset: chart.data.datasets[0], dataIndex: 0, chart });
  }, id);

  const site = [].concat(await label('pd-site-buckets'));
  expect(site.some((l) => /^Country: \S/.test(l))).toBe(true);
  expect(site.join('|')).toContain('Subjects');          // still carries the counts
  expect(site.join('|')).not.toContain('Country: NA');

  // The other two tiers have no parent, so they get no country line at all.
  for (const id of ['pd-study-buckets', 'pd-country-buckets']) {
    const lines = [].concat(await label(id));
    expect(lines.some((l) => l.startsWith('Country:'))).toBe(false);
  }
});

test('re-clicking the active country bar drops an active site with it (#264)', async ({ page }) => {
  const usa = { level: 'country', groupId: 'USA', country: 'USA' };
  const inv1 = { level: 'site', groupId: 'INV-1', invid: 'INV-1', country: 'USA' };

  // A site click adopts its parent country, so this reaches the one state the
  // other toggle tests never build: both filters active at once.
  await clickBucket(page, 'pd-site-buckets', inv1);
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-site-chip')).toBe(true);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(true);

  await clickBucket(page, 'pd-country-buckets', usa);   // the active country bar
  await page.waitForTimeout(300);
  expect(await shown(page, 'pd-filter-country-chip')).toBe(false);
  expect(await shown(page, 'pd-filter-site-chip')).toBe(false);   // dropped with its country
  expect(await shown(page, 'pd-filter-banner')).toBe(false);
});
