// Eligibility report, both modes. Fixtures from
// render-eligibility-fixture.R: basic = gsm.mapping's EXCLUSION on
// gsm.core::lSource; pilot = the same participants with the optional level 1-3
// data. Assertions read chart data and the DOM, not pixels.
const { test, expect } = require('@playwright/test');
const path = require('path');

const BASIC = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility.html');
const PILOT = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility_pilot.html');
const PILOT_NOQUERY = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility_pilot_noquery.html');
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
// Categories whose visible series sum to 0, i.e. empty bars on the category axis.
const zeroCategories = (page) => page.evaluate((ids) => ids.flatMap((id) => {
  const c = document.getElementById(id).gsmChart;
  const h = c.data._spec_.orientation === 'horizontal';
  const total = Object.fromEntries(c.data.labels.map((l) => [l, 0]));
  c.data.datasets.forEach((d, i) => {
    if (!c.isDatasetVisible(i)) return;
    d.data.forEach((p) => { if ((h ? p.y : p.x) in total) total[h ? p.y : p.x] += Number(h ? p.x : p.y) || 0; });
  });
  return Object.keys(total).filter((k) => total[k] === 0).map((k) => `${id}: ${k}`);
}), CHARTS);
const toggleLegend = (page, id, label) => page.evaluate(({ id, label }) => {
  const c = document.getElementById(id).gsmChart;
  const item = c.legend.legendItems.find((it) => it.text === label);
  c.legend.options.onClick.call(c.legend, { native: null }, item, c.legend);
}, { id, label });
const showButtons = (page, level) => page.locator(`#elig-${level}-status-filter button`).allTextContents();
const DETAILS = ['Protocol Deviation details', 'EDC eCRF details', 'EDC Query details', 'EDC PD details'];

// Quote-aware, so details cells with line breaks stay one cell.
function parseCsv(text) {
  const rows = [[]];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (c === '"') quoted = false; else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { rows[rows.length - 1].push(cell); cell = ''; } else if (c === '\n') { rows[rows.length - 1].push(cell); cell = ''; rows.push([]); } else if (c !== '\r') cell += c;
  }
  rows[rows.length - 1].push(cell);
  return rows.filter((r) => r.length > 1 || r[0] !== '');
}

async function downloadCsv(page) {
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator('#ineligibility-listing button', { hasText: 'Download CSV' }).click(),
  ]);
  const text = require('fs').readFileSync(await download.path(), 'utf8');
  // UTF-8 BOM, so Excel imports accented names correctly.
  expect(text.charCodeAt(0)).toBe(0xfeff);
  return parseCsv(text.slice(1));
}

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

  test('the rate chart gets only study-level groups (#371)', async ({ page }) => {
    await open(page, BASIC);
    const levels = await page.evaluate(() => {
      // The widget renames its element to timeSeries--<metric>--<htmlwidget id>.
      const id = document.querySelector('.Widget_TimeSeries').id.split('--').pop();
      const x = JSON.parse(document.querySelector(`script[data-for="${id}"]`).textContent).x;
      return [...new Set(x.dfGroups.map((g) => g.GroupLevel))];
    });
    expect(levels).toEqual(['Study']);
  });

  test('has the Stratification-style tabs and one PD column (#371)', async ({ page }) => {
    await open(page, BASIC);
    expect(await tabs(page, 'study')).toEqual(['Status', 'Flag Sources', 'Criteria (EDC I/E only)']);
    expect(await tabs(page, 'country')).toEqual(['Status', 'Flag Sources', 'Criteria (EDC I/E only)', 'Criteria Map (EDC I/E only)']);
    expect(await tabs(page, 'site')).toEqual(['Status', 'Flag Sources', 'Criteria (EDC I/E only)', 'Criteria Map (EDC I/E only)']);
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

  test('a chart pick matches the listing exactly; a typed filter still matches part of the ID (#371)', async ({ page }) => {
    await open(page, BASIC);
    const row = await page.evaluate(() => Reactable.getState('elig-listing').sortedData[0]);
    const part = row.Site.slice(0, 4);
    await clickBar(page, 'elig-site-status', { GroupID: part, OuterGroupID: row.Country });
    expect(await listingRows(page)).toBe(0);

    await page.click('#elig-chip-site button');
    await page.locator('#elig-listing input[aria-label="Filter Site"]').fill(part);
    await expect.poll(() => listingRows(page)).toBeGreaterThan(0);
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

  test('a site with no criterion case empties the criteria chart (#371)', async ({ page }) => {
    const errors = await open(page, BASIC);
    const site = await page.evaluate(() => {
      const withCases = new Set(Reactable.getState('elig-listing').sortedData.filter((r) => r['Which I/E']).map((r) => r.Site));
      return JSON.parse(document.getElementById('elig-data').textContent).status.site.find((r) => !withCases.has(r.GroupID));
    });
    await clickBar(page, 'elig-site-status', site);
    expect(await categories(page, 'elig-site-criteria')).toEqual([]);
    expect(errors).toEqual([]);
  });

  test('a site click leaves only the site\'s criteria in the criteria chart (#371)', async ({ page }) => {
    await open(page, BASIC);
    const row = await page.evaluate(() => Reactable.getState('elig-listing').sortedData.find((r) => r['Which I/E']));
    await clickBar(page, 'elig-site-status', { GroupID: row.Site, OuterGroupID: row.Country });
    const expected = await page.evaluate(() => [...new Set(Reactable.getState('elig-listing').sortedData
      .flatMap((r) => (r['Which I/E'] || '').split(', ').filter(Boolean)))].sort());
    expect(expected.length).toBeGreaterThan(0);
    expect((await categories(page, 'elig-site-criteria')).sort()).toEqual(expected);
  });

  test('listing rows expand and the CSV exports the on-screen rows (#371)', async ({ page }) => {
    await open(page, BASIC);
    await page.locator('#elig-listing .rt-expander-button').first().click();
    await expect(page.locator('#elig-listing .elig-detail strong').first()).toHaveText(/^(Protocol Deviation|EDC eCRF) \(\d+\)$/);
    const headers = await page.locator('#elig-listing .rt-th').allTextContents();
    expect(headers.filter((h) => /^PD (Date|Term)/.test(h))).toEqual([]);

    await clickBar(page, 'elig-country-status', { GroupID: 'UK', OuterGroupID: null });
    const shown = await listingRows(page);
    const [header, ...rows] = await downloadCsv(page);
    expect(header).toEqual(['Country', 'Site', 'Investigator Name', 'Participant ID', 'Eligibility Status', 'PD', 'EDC eCRF', 'Which I/E', 'Protocol Deviation details']);
    expect(rows.length).toBe(shown);
    expect(new Set(rows.map((r) => r[0]))).toEqual(new Set(['UK']));
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
    await expect(page.locator('body')).not.toContainText('Study-wide', { ignoreCase: true });
    await expect(page.locator('#elig-deep-dive')).toHaveCount(0);
    await expect(page.locator('h2', { hasText: 'Deep Dive' })).toHaveCount(0);
    const headers = await page.locator('#elig-listing .rt-th').allTextContents();
    expect(headers).toEqual(expect.arrayContaining(['Important PD', 'Non-important PD', 'EDC Query', 'EDC PD']));
    expect(errors).toEqual([]);
  });

  test('Status over Time ends on the snapshot the study status chart shows (#371)', async ({ page }) => {
    await open(page, PILOT);
    // Totals per status for one category; the study chart is horizontal, the trend vertical.
    const counts = (page, id, category) => page.evaluate(({ id, category }) => {
      const c = document.getElementById(id).gsmChart;
      const h = c.data._spec_.orientation === 'horizontal';
      const cat = category ?? c.data.labels[c.data.labels.length - 1];
      return Object.fromEntries(c.data.datasets.map((d) => [d.label,
        d.data.filter((p) => (h ? p.y : p.x) === cat).reduce((s, p) => s + Number(h ? p.x : p.y), 0)]));
    }, { id, category });
    expect(await categories(page, 'elig-trend-status')).toHaveLength(2);
    const study = (await categories(page, 'elig-study-status'))[0];
    expect(await counts(page, 'elig-trend-status')).toEqual(await counts(page, 'elig-study-status', study));
  });

  test('bar charts show no zero-count category on load, after a site filter or a legend click (#371)', async ({ page }) => {
    const errors = await open(page, PILOT);
    expect(await zeroCategories(page)).toEqual([]);

    const site = await page.evaluate(() => JSON.parse(document.getElementById('elig-data').textContent)
      .status.site.find((r) => r.Status === 'Ineligible' && r.n === 1));
    await clickBar(page, 'elig-site-status', site);
    expect(await zeroCategories(page)).toEqual([]);
    await clickBar(page, 'elig-site-status', site);

    const sources = (await categories(page, 'elig-study-sources')).length;
    await toggleLegend(page, 'elig-study-sources', 'Ineligible');
    await toggleLegend(page, 'elig-study-criteria', 'Inclusion');
    await toggleLegend(page, 'elig-country-status', 'No Eligibility Risk');
    expect((await categories(page, 'elig-study-sources')).length).toBeLessThan(sources);
    expect(await zeroCategories(page)).toEqual([]);
    // The filter redraws the charts; the hidden series and their empty categories stay hidden.
    await clickBar(page, 'elig-country-status', { GroupID: 'Japan', OuterGroupID: null });
    expect(await zeroCategories(page)).toEqual([]);

    await toggleLegend(page, 'elig-study-sources', 'Ineligible');
    expect((await categories(page, 'elig-study-sources')).length).toBe(sources);
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
    await expect(page.locator('#elig-listing .elig-detail strong').first()).toHaveText(/^(Protocol Deviation|EDC eCRF|EDC Query|EDC PD) \(\d+\)$/);
  });

  test('the CSV adds one details column per source (#371)', async ({ page }) => {
    await open(page, PILOT);
    const shown = await listingRows(page);
    const [header, ...rows] = await downloadCsv(page);
    expect(header.slice(-4)).toEqual(DETAILS);
    expect(rows.length).toBe(shown);
    const details = rows.flatMap((r) => r.slice(-4));
    expect(details.some((d) => /^ID: [^;]+; /.test(d))).toBe(true);
    // Excel's text import splits rows at line breaks even inside quotes.
    expect(rows.flat().filter((c) => /[\r\n]/.test(c))).toEqual([]);
  });
});

test.describe('pilot mode, EDC Query not delivered', () => {
  test('shows EDC Query as N/A and no source bar (#371)', async ({ page }) => {
    const errors = await open(page, PILOT_NOQUERY);
    expect(await datasetLabels(page, 'elig-site-status')).toEqual(['Ineligible', 'Potentially Ineligible', 'No Eligibility Risk']);
    expect(await categories(page, 'elig-study-sources')).not.toContain('EDC Query');
    const headers = await page.locator('#elig-listing .rt-th').allTextContents();
    expect(headers).toContain('EDC Query');
    expect(headers).toContain('EDC PD');
    await expect(page.locator('#elig-listing .rt-td', { hasText: 'N/A' }).first()).toBeVisible();
    expect(errors).toEqual([]);
  });

  test('criteria without iecat_concat are one Not classified series (#371)', async ({ page }) => {
    const errors = await open(page, PILOT_NOQUERY);
    expect(await datasetLabels(page, 'elig-study-criteria')).toEqual(['Not classified']);
    expect(errors).toEqual([]);
  });
});
