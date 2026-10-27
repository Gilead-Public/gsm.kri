// Verifies the 6 initially-hidden "Bar Charts" tabs draw real content once
// revealed (#286). gsm.vizr's bars.js binding renders every widget at page
// load regardless of its tab-pane's display state -- htmlwidgets resolves
// the widget's width from CSS (width:100%) rather than by live-measuring a
// collapsed ancestor, so a hidden pane's canvas already carries a real
// backing-store size and pixel content before its tab is ever clicked (see
// gsm.vizr's tests/playwright/layout.spec.js and the no-reveal-hook comment
// atop bars.js). This spec proves that holds for THIS report by measuring
// both states: the pane genuinely starts collapsed (offsetWidth 0, so the
// test cannot pass vacuously), and the canvas is drawn -- non-zero backing
// store plus non-blank toDataURL -- both before and after the tab reveal.
const { test, expect } = require('@playwright/test');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility.html');

// [sectionId, tabLabel]; "site" is the tabset's default-active tab (visible
// on load, no click needed) and is asserted separately below.
const HIDDEN_TABS = [
  ['country', 'Country'],
  ['source', 'Source'],
  ['criteriasite-edc-ie-data-only', 'Criteria/Site (EDC I/E data only)'],
  ['criteriacountry-edc-ie-data-only', 'Criteria/Country (EDC I/E data only)'],
  ['sitecriteria-edc-ie-data-only', 'Site/Criteria (EDC I/E data only)'],
  ['countrycriteria-edc-ie-data-only', 'Country/Criteria (EDC I/E data only)'],
];

function readCanvasState(page, sectionId) {
  return page.evaluate((id) => {
    const pane = document.getElementById(id);
    const widget = pane.querySelector('.bars.html-widget');
    const canvas = widget ? widget.querySelector('canvas') : null;
    return {
      paneDisplay: getComputedStyle(pane).display,
      paneOffsetWidth: pane.offsetWidth,
      hasCanvas: !!canvas,
      canvasWidth: canvas ? canvas.width : 0,
      canvasHeight: canvas ? canvas.height : 0,
      // toDataURL of a canvas that never drew anything is a short, constant
      // string (a fully transparent PNG); real chart content is far longer.
      dataUrlLength: canvas ? canvas.toDataURL().length : 0,
    };
  }, sectionId);
}

test('the default "Site" tab draws a non-blank canvas without any reveal (#286)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#site canvas', { timeout: 20000 });
  const state = await readCanvasState(page, 'site');
  expect(state.paneDisplay).toBe('block');
  expect(state.canvasWidth).toBeGreaterThan(0);
  expect(state.canvasHeight).toBeGreaterThan(0);
  expect(state.dataUrlLength).toBeGreaterThan(1000);
});

for (const [sectionId, label] of HIDDEN_TABS) {
  test(`"${label}" tab draws a non-zero, non-blank canvas on reveal (#286)`, async ({ page }) => {
    await page.goto(fileUrl);
    // state: 'attached', not the default 'visible' -- the canvas is
    // DELIBERATELY inside a still-hidden tab pane at this point.
    await page.waitForSelector(`#${sectionId} canvas`, { state: 'attached', timeout: 20000 });

    // Establish the pane really was collapsed, or this test proves nothing.
    const before = await readCanvasState(page, sectionId);
    expect(before.paneDisplay).toBe('none');
    expect(before.paneOffsetWidth).toBe(0);

    await page.click(`a[href="#${sectionId}"]`);
    await page.waitForTimeout(300);

    const after = await readCanvasState(page, sectionId);
    expect(after.paneDisplay).toBe('block');
    expect(after.paneOffsetWidth).toBeGreaterThan(0);
    expect(after.hasCanvas).toBe(true);
    expect(after.canvasWidth).toBeGreaterThan(0);
    expect(after.canvasHeight).toBeGreaterThan(0);
    // Real chart content, not a blank/transparent canvas.
    expect(after.dataUrlLength).toBeGreaterThan(1000);
  });
}

// The Site/Criteria and Country/Criteria tabs pass the SAME data through
// criteria_groupBar with bSwapAxes = TRUE -- a mapping swap (which variable
// is the category axis vs. the fill), not an orientation flip (#286). Both
// still draw horizontally; their revealed category axis must differ: Criteria
// by Site groups bars by criterion (4 categories) while Site by Criteria
// groups bars by site (2 categories).
test('bSwapAxes swaps the category axis, not the orientation, across Criteria/Site vs Site/Criteria (#286)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#site canvas', { timeout: 20000 });

  await page.click('a[href="#criteriasite-edc-ie-data-only"]');
  await page.waitForTimeout(300);
  const criteriaBySite = await page.evaluate(() => {
    const c = document.querySelector('#criteriasite-edc-ie-data-only .bars.html-widget').gsmChart;
    return { indexAxis: c.config.options.indexAxis, categories: c.data.labels.slice() };
  });

  await page.click('a[href="#sitecriteria-edc-ie-data-only"]');
  await page.waitForTimeout(300);
  const siteByCriteria = await page.evaluate(() => {
    const c = document.querySelector('#sitecriteria-edc-ie-data-only .bars.html-widget').gsmChart;
    return { indexAxis: c.config.options.indexAxis, categories: c.data.labels.slice() };
  });

  // Both horizontal (indexAxis 'y') -- the swap is the mapping, not the
  // orientation.
  expect(criteriaBySite.indexAxis).toBe('y');
  expect(siteByCriteria.indexAxis).toBe('y');
  expect(criteriaBySite.categories.sort()).toEqual(['E010', 'E020', 'I001', 'I002']);
  expect(siteByCriteria.categories.sort()).toEqual(['Site01', 'Site02']);
});

// Pins the dataset/series ORDER (unsorted -- this is exactly what the
// category-sorted assertions above deliberately throw away). The equivalence
// diff against the pre-migration baseline (#286 equivalence gate) found this
// array order UNCHANGED end to end -- both renders emit
// ["No Eligibility Risk", "Ineligible"] / ["Site01", "Site02"] in the same
// positions. What differs, and is NOT asserted here because it is a rendering
// -library convention rather than a data fact, is which end of the stack each
// array position draws at: Chart.js stacks datasets[0] closest to the axis
// origin, plotly stacked its first trace farthest from it -- so the same
// array order produces visually swapped stacking on the Site chart (see the
// fix report for the before/after screenshot comparison). A future change
// that reorders these arrays would be a real regression; this test exists to
// catch that, not to assert anything about on-screen stacking direction.
test('dataset order is preserved end to end on the Site chart (#286)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#site canvas', { timeout: 20000 });
  const order = await page.evaluate(() =>
    document.querySelector('#site .bars.html-widget').gsmChart.data.datasets.map((d) => d.label)
  );
  expect(order).toEqual(['No Eligibility Risk', 'Ineligible']);
});

test('dataset order is preserved end to end on the Criteria/Site chart (#286)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('#site canvas', { timeout: 20000 });
  await page.click('a[href="#criteriasite-edc-ie-data-only"]');
  await page.waitForTimeout(300);
  const order = await page.evaluate(() =>
    document.querySelector('#criteriasite-edc-ie-data-only .bars.html-widget').gsmChart.data.datasets.map((d) => d.label)
  );
  expect(order).toEqual(['Site01', 'Site02']);
});
