const { test, expect } = require('@playwright/test');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report.html');

test.beforeEach(async ({ page }) => {
  await page.goto(fileUrl);
  // Plotly initialises asynchronously; wait for the site bar's plotly widget.
  await page.waitForSelector('#pd-site-buckets .plotly', { timeout: 20000 });
  await page.waitForTimeout(500); // let multicategory ticks paint
});

// Aggregate the multicategory axis across every trace of a chart: bars carry it
// on x, scatters on y. Returns {outer, inner} (the two tiers) or null if flat.
// This reads the data shape directly -- deterministic, font/headless-agnostic,
// and exactly the "two-tier axis is present" contract spec step 6(a) asks for.
async function readMultiAxis(page, containerId) {
  return await page.evaluate((id) => {
    const el = document.querySelector('#' + id + ' .plotly');
    const outer = [], inner = [];
    let is2d = false;
    el.data.forEach(function(tr) {
      const axis = (Array.isArray(tr.x) && Array.isArray(tr.x[0])) ? tr.x
                 : (Array.isArray(tr.y) && Array.isArray(tr.y[0])) ? tr.y
                 : null;
      if (axis) {
        is2d = true;
        axis[0].forEach((v) => outer.push(v));
        axis[1].forEach((v) => inner.push(v));
      }
    });
    return is2d ? { outer, inner } : null;
  }, containerId);
}

// Expected tiers reflect the fixture's DEATH cohort, not the enrolled set: the
// bars count every enrolled group (.drop=FALSE) so INV-2/CAN appear, but the
// scatters plot only the two deaths (both at INV-1/USA), so CAN/INV-2 are absent.
const INTERACTIVE = [
  { id: 'pd-country-buckets', outer: ['ST01'],       inner: ['USA', 'CAN'] },
  { id: 'pd-site-buckets',    outer: ['USA', 'CAN'], inner: ['INV-1', 'INV-2'] },
  { id: 'pd-country-scatter', outer: ['ST01'],       inner: ['USA'] },
  { id: 'pd-site-scatter',    outer: ['USA'],        inner: ['INV-1'] }
];

for (const chart of INTERACTIVE) {
  test(`${chart.id} carries a two-tier multicategory axis`, async ({ page }) => {
    const axis = await readMultiAxis(page, chart.id);
    expect(axis).not.toBeNull(); // 2-D [[outer],[inner]] present, not a flat axis
    for (const o of chart.outer) expect(axis.outer).toContain(o);
    for (const i of chart.inner) expect(axis.inner).toContain(i);
    // Sanity-check Plotly actually DREW the outer bracket: the outer label is
    // rendered as tick text inside this chart div. Assert toBeAttached, not
    // toBeVisible -- the scatters live in a collapsed second tab (### Rand ->
    // Death), so their bracket is in the DOM but hidden until the tab is opened.
    const loc = page.locator('#' + chart.id);
    for (const o of chart.outer) {
      await expect(loc.getByText(o, { exact: true }).first()).toBeAttached();
    }
  });
}

test('a REAL multicategory bar click delivers points[0].x = [outer, inner]', async ({ page }) => {
  // RUNTIME CONTRACT (do not replace with a synthesized event): the click
  // handlers read data.points[0].x[1], assuming a real Plotly multicategory
  // click returns x = [outer, inner]. Probe the payload Plotly actually
  // delivers so a shape mismatch fails the suite instead of silently breaking
  // click-to-filter in production.
  await page.evaluate(() => {
    const el = document.querySelector('#pd-country-buckets .plotly');
    window.__clickX = null;
    el.on('plotly_click', function(d) { window.__clickX = d.points[0].x; });
  });
  // Click a REAL rendered bar with non-zero height: in this fixture the first
  // g.points path is a zero-count (zero-height) bar that cannot receive a click,
  // so scan for the first bar with a real bounding box. force:true gets past
  // Plotly's transparent drag overlay.
  const bars = page.locator('#pd-country-buckets g.points path');
  const barCount = await bars.count();
  let bar = null;
  for (let i = 0; i < barCount; i++) {
    const box = await bars.nth(i).boundingBox();
    if (box && box.height > 1) {
      bar = bars.nth(i);
      break;
    }
  }
  expect(bar).not.toBeNull();
  await bar.scrollIntoViewIfNeeded();
  await bar.click({ force: true });
  const x = await page.evaluate(() => window.__clickX);
  expect(Array.isArray(x)).toBe(true); // multicategory => array, not a bare string
  expect(x.length).toBe(2); //            [outer, inner]
  // The same real click must drive the filter banner with the inner label.
  await expect(page.locator('#pd-filter-banner')).toBeVisible();
  await expect(page.locator('#pd-filter-text')).toContainText(x[1]);
});

test('clicking a country filters the site charts, leaves NO empty slot, shows the banner', async ({ page }) => {
  // Drive the registered plotly_click handler deterministically (the real-click
  // shape is covered by the test above; here we exercise the filter wiring).
  // The handler reads points[0].x[1] = country.
  await page.evaluate(() => {
    const el = document.querySelector('#pd-country-buckets .plotly');
    el.emit('plotly_click', { points: [{ x: ['ST01', 'USA'] }] });
  });
  await expect(page.locator('#pd-filter-banner')).toBeVisible();
  await expect(page.locator('#pd-filter-country-row')).toBeVisible();
  await expect(page.locator('#pd-filter-text')).toContainText('USA');
  // categoryarray hack is deleted: a reindexed multicategory axis must
  // re-derive its ticks from the data, so the filtered-out CAN site (INV-2)
  // leaves NO empty slot. This is the deterministic check the self-baselined
  // screenshot cannot make.
  const siteChart = page.locator('#pd-site-buckets');
  await expect(siteChart.getByText('INV-1', { exact: true }).first()).toBeVisible();
  await expect(siteChart.getByText('INV-2', { exact: true })).toHaveCount(0);
});

test('reset restores all sites', async ({ page }) => {
  await page.evaluate(() => {
    document.querySelector('#pd-country-buckets .plotly')
      .emit('plotly_click', { points: [{ x: ['ST01', 'USA'] }] });
  });
  await expect(page.locator('#pd-filter-banner')).toBeVisible();
  await page.locator('#pd-filter-reset').click();
  await expect(page.locator('#pd-filter-country-row')).toBeHidden();
});
