const { test, expect } = require('@playwright/test');
const path = require('path');
const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report.html');

test.beforeEach(async ({ page }) => {
  await page.goto(fileUrl);
  // The reason charts live in the 3rd tab (Buckets is active by default), so
  // their canvas is in the DOM but hidden. htmlwidgets still render it on load;
  // wait for attachment, not visibility, and read the chart via its handle.
  await page.waitForSelector('#pd-study-reasons canvas', { state: 'attached', timeout: 20000 });
});

test('reason charts render Chart.js canvases, not Plotly (#264)', async ({ page }) => {
  for (const id of ['pd-study-reasons', 'pd-country-reasons']) {
    expect(await page.locator('#' + id + ' canvas').count()).toBeGreaterThan(0);
    expect(await page.locator('#' + id + ' .plotly').count()).toBe(0);
  }
});

test('selecting a country swaps the country reason slice (#264)', async ({ page }) => {
  const labels = () => page.evaluate(() => {
    const c = document.querySelector('#pd-country-reasons').gsmChart;
    return c.data.labels.slice();
  });
  const before = await labels();
  // A country with fewer reasons than the study-wide __ALL__ slice; the reactive
  // handler narrows the bar to that country via helpers.updateData.
  await page.evaluate(() => document.dispatchEvent(new CustomEvent('pdBucketFilterChanged',
    { bubbles: true, detail: { country: 'USA', invid: null } })));
  await page.waitForTimeout(300);
  const after = await labels();
  expect(after).not.toEqual(before);
});
