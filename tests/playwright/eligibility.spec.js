// Eligibility report, both modes (gsm.roadmap#113). Fixtures from
// render-eligibility-fixture.R: basic = gsm.mapping's EXCLUSION on
// gsm.core::lSource; pilot = the same participants with the optional level 1-3
// data. Assertions read chart data and the DOM, not pixels.
const { test, expect } = require('@playwright/test');
const path = require('path');

const BASIC = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility.html');
const PILOT = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility_pilot.html');
const CHARTS = ['study', 'country', 'site'].flatMap((l) => ['status', 'sources', 'criteria'].map((k) => `elig-${l}-${k}`));

// The bubbling event gsm.vizr's bars() dispatches on a bar click, so the test
// does not depend on bar geometry.
function clickBar(page, chartId, row) {
  return page.evaluate(({ chartId, row }) => {
    document.getElementById(chartId).dispatchEvent(new CustomEvent('gsm-viz-select', {
      bubbles: true,
      detail: { type: 'click', chartId, category: row.GroupID, datum: row, metadata: { chartId } },
    }));
  }, { chartId, row });
}

const datasetLabels = (page, id) => page.evaluate((id) =>
  document.getElementById(id).gsmChart.data.datasets.map((d) => d.label), id);
const categories = (page, id) => page.evaluate((id) =>
  document.getElementById(id).gsmChart.data.labels.slice(), id);
const listingRows = (page, id = 'elig-listing') => page.evaluate((id) => Reactable.getState(id).sortedData.length, id);
const tabs = (page, section) => page.locator(`#${section} > .nav-pills a`).allTextContents();
const showButtons = (page, level) => page.locator(`#elig-${level}-status-filter button`).allTextContents();

async function open(page, url) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url);
  await page.waitForFunction((ids) => window.Reactable && ids.every((id) => {
    const el = document.getElementById(id);
    return el && el.gsmChart;
  }), CHARTS, { timeout: 30000 });
  return errors;
}

test.describe('basic mode', () => {
  test('shows two statuses and never Potentially Ineligible (#371)', async ({ page }) => {
    const errors = await open(page, BASIC);
    await expect(page.locator('.elig-card')).toHaveCount(3);
    expect(await datasetLabels(page, 'elig-site-status')).toEqual(['Ineligible', 'No Eligibility Risk']);
    expect(await showButtons(page, 'site')).toEqual(['All', 'With Ineligible']);
    expect(await page.locator('body').innerText()).not.toContain('Potentially');
    expect(await page.locator('#status-over-time').count()).toBe(0);
    expect(await page.locator('#deep-dive-listing').count()).toBe(0);
    expect(errors).toEqual([]);
  });

  test('has the Stratification-style tabs and one PD column (#371)', async ({ page }) => {
    await open(page, BASIC);
    expect(await tabs(page, 'study')).toEqual(['Status', 'Flag Sources', 'Criteria (EDC I/E only)']);
    expect(await tabs(page, 'country')).toEqual(['Status', 'Flag Sources', 'Criteria (EDC I/E only)', 'Criteria Map (EDC I/E only)']);
    expect(await categories(page, 'elig-study-sources')).toEqual(['Protocol Deviation', 'EDC eCRF']);
    const headers = await page.locator('#elig-listing .rt-th').allTextContents();
    expect(headers).toEqual(expect.arrayContaining(['PD', 'EDC eCRF', 'Which I/E', 'Investigator Name']));
    expect(headers).not.toContain('Source');
  });

  test('a country click filters the site chart, criteria map and listing; the chip clears it (#371)', async ({ page }) => {
    await open(page, BASIC);
    const allRows = await listingRows(page);
    const allSites = (await categories(page, 'elig-site-status')).length;
    await clickBar(page, 'elig-country-status', { GroupID: 'Japan', OuterGroupID: null });

    await expect(page.locator('#elig-chip-country .elig-chip-value')).toHaveText('Japan');
    const japanSites = await categories(page, 'elig-site-status');
    expect(japanSites.length).toBeGreaterThan(0);
    expect(japanSites.length).toBeLessThan(allSites);
    const rows = await listingRows(page);
    expect(rows).toBeGreaterThan(0);
    expect(rows).toBeLessThan(allRows);
    const countries = await page.evaluate(() => Reactable.getState('elig-listing').sortedData.map((r) => r.Country));
    expect(new Set(countries)).toEqual(new Set(['Japan']));
    await expect(page.locator('#elig-country-map tbody tr')).toHaveCount(1);

    await page.click('#elig-chip-country button');
    expect(await listingRows(page)).toBe(allRows);
    expect((await categories(page, 'elig-site-status')).length).toBe(allSites);
  });

  test('the criteria map shows no empty column (#371)', async ({ page }) => {
    await open(page, BASIC);
    await clickBar(page, 'elig-country-status', { GroupID: 'UK', OuterGroupID: null });
    await page.locator('#site > .nav-pills a', { hasText: 'Criteria Map' }).click();
    const emptyColumns = await page.evaluate(() => {
      const table = document.querySelector('#elig-site-map table');
      const n = table.querySelectorAll('thead th').length;
      const empty = [];
      for (let c = 1; c < n - 1; c++) {
        const cells = Array.from(table.querySelectorAll(`tbody tr > :nth-child(${c + 1})`));
        if (cells.every((td) => td.textContent.trim() === '')) empty.push(c);
      }
      return empty;
    });
    expect(emptyColumns).toEqual([]);
  });

  test('listing rows expand and the CSV exports the on-screen rows (#371)', async ({ page }) => {
    await open(page, BASIC);
    await page.locator('#elig-listing .rt-expander-button').first().click();
    await expect(page.locator('#elig-listing .elig-detail').first()).toContainText('EDC I/E criteria');

    await clickBar(page, 'elig-country-status', { GroupID: 'UK', OuterGroupID: null });
    const shown = await listingRows(page);
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#ineligibility-listing button', { hasText: 'Download CSV' }).click(),
    ]);
    const csv = require('fs').readFileSync(await download.path(), 'utf8').trim().split('\n');
    expect(csv.length - 1).toBe(shown);
  });
});

test.describe('pilot mode', () => {
  test('shows three statuses, total risk and the pilot-only sections (#371)', async ({ page }) => {
    const errors = await open(page, PILOT);
    await expect(page.locator('.elig-card')).toHaveCount(4);
    await expect(page.locator('.elig-card-label', { hasText: 'Total risk' })).toHaveCount(1);
    expect(await datasetLabels(page, 'elig-site-status')).toEqual(['Ineligible', 'Potentially Ineligible', 'No Eligibility Risk']);
    expect(await showButtons(page, 'country')).toEqual(['All', 'With any risk', 'With Ineligible']);
    expect(await categories(page, 'elig-study-sources')).toEqual(['Important PD', 'Non-important PD', 'EDC eCRF', 'EDC Query', 'EDC PD']);
    await expect(page.locator('#status-over-time canvas')).toHaveCount(1);
    await expect(page.locator('#elig-deep-dive')).toHaveCount(1);
    const headers = await page.locator('#elig-listing .rt-th').allTextContents();
    expect(headers).toEqual(expect.arrayContaining(['Important PD', 'Non-important PD', 'EDC Query', 'EDC PD']));
    expect(errors).toEqual([]);
  });

  test('Show buttons keep only groups with the chosen statuses (#371)', async ({ page }) => {
    await open(page, PILOT);
    const all = (await categories(page, 'elig-site-status')).length;
    await page.locator('#elig-site-status-filter button', { hasText: 'With Ineligible' }).click();
    const inel = (await categories(page, 'elig-site-status')).length;
    await page.locator('#elig-site-status-filter button', { hasText: 'With any risk' }).click();
    const risk = (await categories(page, 'elig-site-status')).length;
    expect(inel).toBeLessThanOrEqual(risk);
    expect(risk).toBeLessThanOrEqual(all);
    await expect(page.locator('#elig-site-status-filter .elig-status-count')).toHaveText(`Showing ${risk} of ${all} sites`);
  });

  test('expanding a listing row shows the records behind the status (#371)', async ({ page }) => {
    await open(page, PILOT);
    await page.locator('#elig-listing .rt-expander-button').first().click();
    await expect(page.locator('#elig-listing .elig-detail').first()).toContainText('Records behind this status');
  });

  test('a site click filters the deep dive (#371)', async ({ page }) => {
    await open(page, PILOT);
    const site = await page.evaluate(() => Reactable.getState('elig-deep-dive').sortedData[0]);
    await clickBar(page, 'elig-site-status', { GroupID: site.Site, OuterGroupID: site.Country });
    const sites = await page.evaluate(() => Reactable.getState('elig-deep-dive').sortedData.map((r) => r.Site));
    expect(new Set(sites)).toEqual(new Set([site.Site]));
  });
});
