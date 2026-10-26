const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const FULL = 'file://' + path.resolve(__dirname, 'fixture', 'RM.html');
const DEGRADED = 'file://' + path.resolve(__dirname, 'fixture', 'RM_degraded.html');

// Facts of rm_Fixture() in tests/testthat/helper-rm.R (render-rm-fixture.R):
// A, B (US/S1), C (US/S2), D, E (JP/S3); repeating windows in A weight,
// B pulse, D weight and D height.

// The same bubbling event gsm.vizr's bars() dispatches on a bar click, so the
// test does not depend on bar geometry that zoom can move.
function clickBar(page, chartId, row) {
  return page.evaluate(({ chartId, row }) => {
    document.getElementById(chartId).dispatchEvent(new CustomEvent('gsm-viz-select', {
      bubbles: true,
      detail: { type: 'click', chartId, category: row.GroupID, datum: row },
    }));
  }, { chartId, row });
}

const state = (page) => page.evaluate(() => {
  const api = (id) => jQuery('#' + id + ' table.dataTable').DataTable();
  const col = (id, name) => api(id).settings()[0].aoColumns.findIndex((c) => c.name === name);
  const rows = (id) => api(id).rows({ search: 'applied' }).data().toArray();
  const shown = (id) => document.getElementById(id).closest('[data-rm-shape-view]').style.display !== 'none';
  return {
    overview: document.querySelector('#rm-overview p').textContent,
    count: document.getElementById('rm-count').textContent,
    tiles: Array.from(document.querySelectorAll('#rm-tiles tbody th[data-subjid]')).map((th) => th.dataset.subjid),
    selectedTile: Array.from(document.querySelectorAll('#rm-tiles tr.rm-tiles-sel th[data-subjid]')).map((th) => th.dataset.subjid),
    tileColumns: [...new Set(document.getElementById('rm-tiles').gsmChart.data.map((t) => t.column))],
    vitals: rows('rm-vitals').map((r) => r[col('rm-vitals', 'subjid')] + ' ' + r[col('rm-vitals', 'vital')]),
    compact: document.getElementById('rm-vitals-wrap').classList.contains('rm-compact'),
    shape: shown('rm-dt-wide') ? 'wide' : shown('rm-dt-long') ? 'long' : 'none',
    wide: rows('rm-dt-wide').map((r) => r[col('rm-dt-wide', 'subjid')]),
    wideVitals: api('rm-dt-wide').settings()[0].aoColumns
      .filter((c, i) => ['weight', 'pulse', 'height'].includes(c.name) && api('rm-dt-wide').column(i).visible())
      .map((c) => c.name),
    long: rows('rm-dt-long').map((r) => r[col('rm-dt-long', 'subjid')] + ' ' + r[col('rm-dt-long', 'vital')]),
    dtOnly: document.getElementById('rm-dt-only').checked,
    dtOnlyLabel: document.getElementById('rm-dt-only-label').textContent,
    chips: Array.from(document.querySelectorAll('.rm-chip'))
      .filter((c) => c.style.display !== 'none')
      .map((c) => c.querySelector('.rm-chip-value').textContent),
  };
});

async function downloadCsv(page, selector) {
  const [download] = await Promise.all([page.waitForEvent('download'), page.click(selector)]);
  return fs.readFileSync(await download.path(), 'utf8').replace(/^\uFEFF/, '').trim().split('\n');
}

test.describe('Repeat Measurements report', () => {
  let errors;
  test.beforeEach(async ({ page }) => {
    errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(FULL);
    await page.waitForFunction(() => document.querySelectorAll('#rm-tiles tbody tr').length > 0);
  });
  test.afterEach(() => expect(errors).toEqual([]));

  test('opens on the study with repeating vitals listed and the Wide data table (#344, #346, #347)', async ({ page }) => {
    const s = await state(page);
    expect(s.overview).toBe('Study: 5 enrolled participants');
    expect(s.count).toBe('5 / 5 participants selected');
    expect(s.tiles).toEqual(['A', 'B', 'D', 'C', 'E']);
    expect(s.vitals.sort()).toEqual(['A weight', 'B pulse', 'D height', 'D weight']);
    expect(s.compact).toBe(false);
    expect(s.chips).toEqual([]);
    // Wide by default: A, B and D's records (4 + 4 + 6), every vital.
    expect(s.shape).toBe('wide');
    expect(s.wide).toHaveLength(14);
    expect(s.wideVitals).toEqual(['weight', 'pulse', 'height']);
    expect(s.dtOnly).toBe(true);
    expect(s.dtOnlyLabel).toBe('Only participants with a repeat window');
    await expect(page.locator('#rm-dt-wide tbody td.rm-rw')).not.toHaveCount(0);
    // The in-repo widget replaces the provisional gsm.viz 2.5.0 tiles bundle.
    expect(await page.evaluate(() => document.documentElement.outerHTML.includes('2.5.0-615'))).toBe(false);
  });

  test('a vital group filters the charts, tiles and listing (#344)', async ({ page }) => {
    await page.click('[data-rm-group="HR"]');
    const s = await state(page);
    expect(s.tileColumns).toEqual(['HR']);
    expect(s.vitals).toEqual(['B pulse']);
    expect(s.wideVitals).toEqual(['pulse']);
    expect([...new Set(s.wide)]).toEqual(['B']);
    await expect(page.locator('[data-rm-vital="weight"]').first()).toBeHidden();
    await expect(page.locator('[data-rm-vital="pulse"]').first()).toBeAttached();
  });

  test('country and site bars filter every section and show chips (#344, #345)', async ({ page }) => {
    await clickBar(page, 'rm-country-weight', { GroupID: 'JP', Level: 'country' });
    let s = await state(page);
    expect(s.overview).toBe('JP: 2 enrolled participants');
    expect(s.count).toBe('2 / 5 participants selected');
    expect(s.tiles).toEqual(['D', 'E']);
    expect([...new Set(s.wide)]).toEqual(['D']);
    expect(s.vitals.sort()).toEqual(['D height', 'D weight']);
    expect(s.chips).toEqual(['JP']);

    await clickBar(page, 'rm-site-weight', { GroupID: 'S1', OuterGroupID: 'US', Level: 'site' });
    s = await state(page);
    expect(s.tiles).toEqual(['A', 'B']);
    expect(s.chips).toEqual(['US', 'S1']);
    await page.click('#rm-chip-site button');
    await page.click('#rm-chip-country button');
    expect((await state(page)).tiles).toHaveLength(5);
  });

  test('site labels take the colour of the site KRI flag (#345)', async ({ page }) => {
    const color = await page.evaluate(() => {
      const c = document.getElementById('rm-site-weight').gsmChart;
      const axis = c.config.options.indexAxis === 'y' ? 'y' : 'x';
      const i = c.data.labels.indexOf('S1');
      return c.config.options.scales[axis].ticks.color({ index: i });
    });
    // S1 weight is flagged -2 (red) in rm_FixtureResults().
    expect(color).toBe('#FF5859');
  });

  test('the participant listing switches labels, sorts, searches and downloads (#347)', async ({ page }) => {
    const firstCell = () => page.locator('#rm-tiles tbody tr').first().locator('td').first();
    await expect(firstCell()).toContainText('2/2');
    await expect(firstCell()).toContainText('100%');
    await page.click('[data-rm-label="rate"]');
    await expect(firstCell()).not.toContainText('2/2');
    await page.click('[data-rm-label="nd"]');
    await expect(firstCell()).not.toContainText('100%');

    await page.selectOption('#rm-tiles-sort', 'subjid');
    expect((await state(page)).tiles).toEqual(['A', 'B', 'C', 'D', 'E']);
    await page.fill('#rm-tiles-search', 'JP');
    expect((await state(page)).tiles).toEqual(['D', 'E']);

    const [download] = await Promise.all([page.waitForEvent('download'), page.click('#rm-tiles-csv')]);
    const lines = fs.readFileSync(await download.path(), 'utf8').trim().split('\n');
    expect(lines[0]).toBe('country,invid,subjid,vital,flag,Numerator,Denominator,rate');
    expect(lines).toHaveLength(1 + 2 * 6);
  });

  test('a participant label or tile click filters the report and a second click clears it (#346, #347)', async ({ page }) => {
    await page.locator('#rm-tiles td.rm-tiles-c[data-subjid="A"]').first().click();
    let s = await state(page);
    expect(s.chips).toEqual(['A']);
    expect(s.count).toBe('1 / 5 participants selected');
    expect(s.overview).toBe('Participant A: 1 enrolled participant');
    expect(s.selectedTile).toEqual(['A']);
    expect(s.vitals).toHaveLength(7);
    expect(s.compact).toBe(true);
    expect(s.dtOnly).toBe(false);
    expect(s.wide).toEqual(['A', 'A', 'A', 'A']);
    // The listing scopes to A and never gains columns or nested rows.
    await expect(page.locator('#rm-tiles thead th')).toHaveCount(7);
    await expect(page.locator('#rm-tiles tbody tr')).toHaveCount(1);

    await page.locator('#rm-tiles th[data-subjid="A"]').click();
    s = await state(page);
    expect(s.chips).toEqual([]);
    expect(s.vitals).toHaveLength(4);
    expect(s.compact).toBe(false);
    expect(s.dtOnly).toBe(true);
    expect(s.wide).toHaveLength(14);
  });

  test('the keyboard selects and clears a participant from the listing (#347)', async ({ page }) => {
    await page.locator('#rm-tiles th[data-subjid="B"]').focus();
    await page.keyboard.press('Enter');
    expect((await state(page)).chips).toEqual(['B']);
    // Focus survives the re-render, so a second key press clears.
    await expect(page.locator('#rm-tiles th[data-subjid="B"]')).toBeFocused();
    await page.keyboard.press(' ');
    expect((await state(page)).chips).toEqual([]);
  });

  test('a vitals listing row filters to its participant and a second click clears it (#346)', async ({ page }) => {
    const row = page.locator('#rm-vitals tbody tr').first().locator('td').nth(2);
    await expect(row).toHaveText('A');
    await row.click();
    let s = await state(page);
    expect(s.chips).toEqual(['A']);
    expect(s.vitals).toHaveLength(7);
    await page.locator('#rm-vitals tbody tr').first().locator('td').nth(2).click();
    s = await state(page);
    expect(s.chips).toEqual([]);
    expect(s.vitals).toHaveLength(4);
    // No second level.
    expect(await page.locator('#rm-records, #rm-back, #rm-all-records').count()).toBe(0);
  });

  test('the vitals listing shows the vital and flag rate with details on hover (#346)', async ({ page }) => {
    const headers = await page.locator('#rm-vitals thead th').allTextContents();
    expect(headers).toEqual(['Country', 'Site', 'Participant', 'Vital', 'Flag \u00b7 rate', 'Measurements in order (W = 3)']);
    const first = page.locator('#rm-vitals tbody tr').first();
    await expect(first.locator('td').nth(3).locator('span').first()).toHaveAttribute('title', 'kri0020a');
    await expect(first.locator('td').nth(4)).toHaveText('100%');
    await expect(first.locator('.rm-fr')).toHaveAttribute('title', /kri0020a · Red · measured 4 · N 2 of D 2/);
    const csv = await downloadCsv(page, '#rm-vitals .buttons-csv');
    expect(csv[0]).toContain('"Metric"');
    expect(csv[0]).toContain('"Numerator"');
    expect(csv[0]).toContain('"Denominator"');
    expect(csv[0]).toContain('"Rate"');
    expect(csv).toHaveLength(1 + 4);
  });

  test('the data table switches between Wide and Long and filters to a clicked participant (#346)', async ({ page }) => {
    await page.click('[data-rm-shape="long"]');
    let s = await state(page);
    expect(s.shape).toBe('long');
    expect(s.dtOnlyLabel).toBe('Only vitals with a repeat window');
    // A weight 4, B pulse 4, D weight 6, D height 3.
    expect(s.long).toHaveLength(17);
    await page.uncheck('#rm-dt-only');
    expect((await state(page)).long).toHaveLength(26);
    await page.check('#rm-dt-only');

    const longCsv = await downloadCsv(page, '#rm-dt-long .buttons-csv');
    expect(longCsv[0]).toBe('"Country","Site","Participant","Vital","Metric","#","Visit","Date","Value","In repeat window"');
    expect(longCsv).toHaveLength(1 + 17);

    await page.locator('#rm-dt-long tbody tr').first().locator('td').nth(2).click();
    s = await state(page);
    expect(s.chips).toEqual(['A']);
    expect(s.long).toHaveLength(7);
    await page.click('[data-rm-shape="wide"]');
    s = await state(page);
    expect(s.shape).toBe('wide');
    expect(s.wide).toEqual(['A', 'A', 'A', 'A']);
    await page.locator('#rm-dt-wide tbody tr').first().locator('td').nth(2).click();
    expect((await state(page)).chips).toEqual([]);

    await page.click('[data-rm-group="HR"]');
    const wideCsv = await downloadCsv(page, '#rm-dt-wide .buttons-csv');
    expect(wideCsv[0]).toBe('"Country","Site","Participant","Visit","Date","Performed","Heart rate","pulse_in_repeat_window"');
    expect(wideCsv).toHaveLength(1 + 4);
  });

  test('the filter strip floats over the data table (#344)', async ({ page }) => {
    await page.locator('#rm-dt-wide').scrollIntoViewIfNeeded();
    await page.locator('#rm-dt-wide tbody tr').first().locator('td').nth(2).click();
    const box = await page.locator('#rm-filter-strip').boundingBox();
    expect(box.y).toBeGreaterThanOrEqual(0);
    expect(box.y).toBeLessThan(120);
    await expect(page.locator('#rm-count')).toHaveText(/1 \/ 5 participants selected/);
  });

  test('values can be hidden from the vitals listing (#346)', async ({ page }) => {
    await page.uncheck('#rm-show-values');
    expect((await state(page)).compact).toBe(true);
    await page.uncheck('#rm-only-repeat');
    expect((await state(page)).vitals).toHaveLength(35);
  });
});

test('the degraded report explains what is missing and does not error (#344)', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(DEGRADED);
  await expect(page.locator('body')).toContainText('No vital signs recorded.');
  await expect(page.locator('body')).toContainText('not in this study');
  expect(errors).toEqual([]);
});
