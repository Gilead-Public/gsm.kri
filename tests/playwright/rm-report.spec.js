const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const FULL = 'file://' + path.resolve(__dirname, 'fixture', 'RM.html');
const DEGRADED = 'file://' + path.resolve(__dirname, 'fixture', 'RM_degraded.html');
const BP = 'file://' + path.resolve(__dirname, 'fixture', 'RM_bp.html');

// Facts of rm_Fixture() in tests/testthat/helper-rm.R (render-rm-fixture.R):
// A, B (US/S1), C (US/S2), D, E (JP/S3); repeating windows in A weight (2/2),
// B pulse (1/2), D weight (1/4) and D height (1/1). Under the default count
// rule (Amber 2, Red 3) only A weight is flagged, Amber.

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
    group: document.querySelector('[data-rm-group][aria-pressed="true"]').dataset.rmGroup,
  };
});

// Participant flags by "subjid vital" from the tiles, the listing and the overview.
const flags = (page) => page.evaluate(() => {
  const api = jQuery('#rm-vitals table.dataTable').DataTable();
  const cols = api.settings()[0].aoColumns;
  const col = (name) => cols.findIndex((c) => c.name === name);
  const tiles = {};
  document.getElementById('rm-tiles').gsmChart.data.forEach((t) => { tiles[t.subjid + ' ' + t.vital] = t.flag; });
  const listing = {};
  api.rows().data().toArray().forEach((r) => { listing[r[col('subjid')] + ' ' + r[col('vital')]] = r[col('flag')]; });
  const overview = {};
  document.querySelectorAll('#rm-overview tr[data-rm-overview]').forEach((tr) => {
    const td = tr.querySelectorAll('td');
    overview[tr.dataset.rmOverview] = { evaluable: +td[2].textContent, amber: +td[6].textContent, red: +td[7].textContent };
  });
  const rule = Array.from(document.querySelectorAll('.rm-rule-text')).map((el) => el.textContent.replace(/\s+/g, ' '));
  return { tiles, listing, overview, rule };
});

async function setInput(page, id, value) {
  await page.fill('#' + id, String(value));
  await page.dispatchEvent('#' + id, 'change');
}

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
    // Values are hidden by default.
    expect(s.compact).toBe(true);
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
    expect(s.compact).toBe(true);
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

  test('the vitals listing shows the vital, measures and flag rate with details on hover (#346)', async ({ page }) => {
    const headers = await page.locator('#rm-vitals thead th').allTextContents();
    expect(headers).toEqual(['Country', 'Site', 'Participant', 'Vital', 'Measures', 'Flag \u00b7 rate', 'Measurements in order (W = 3)']);
    const first = page.locator('#rm-vitals tbody tr').first();
    await expect(first.locator('td').nth(3).locator('span').first()).toHaveAttribute('title', 'kri0020a');
    // A weight: 70 70 70 70 is 1 unique value of 4.
    await expect(first.locator('td').nth(4)).toHaveText('1 / 4');
    await expect(first.locator('td').nth(5)).toHaveText('100%');
    await expect(first.locator('.rm-fr')).toHaveAttribute('title', /kri0020a · Amber · measured 4 · N 2 of D 2/);
    // Each value, including the compact blocks, has its visit on hover.
    const firstValue = first.locator('.rm-vals b').first();
    await expect(firstValue).toHaveAttribute('title', '#1 · V1 · 2024-01-01 · in a repeat window');
    await page.check('#rm-show-values');
    await expect(page.locator('#rm-vitals tbody tr').first().locator('.rm-vals b').nth(3))
      .toHaveAttribute('title', '#4 · V4 · 2024-01-04 · in a repeat window');
    const csv = await downloadCsv(page, '#rm-vitals .buttons-csv');
    expect(csv[0]).toContain('"Measures"');
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

  test('values are hidden by default and can be shown in the vitals listing (#346)', async ({ page }) => {
    await expect(page.locator('#rm-show-values')).not.toBeChecked();
    await page.check('#rm-show-values');
    expect((await state(page)).compact).toBe(false);
    await page.uncheck('#rm-show-values');
    expect((await state(page)).compact).toBe(true);
    await page.uncheck('#rm-only-repeat');
    expect((await state(page)).vitals).toHaveLength(35);
  });

  test('reset filters clears the vital group, country, site and participant (#344)', async ({ page }) => {
    await page.click('[data-rm-group="Weight"]');
    await clickBar(page, 'rm-site-weight', { GroupID: 'S1', OuterGroupID: 'US', Level: 'site' });
    await page.locator('#rm-tiles th[data-subjid="A"]').click();
    let s = await state(page);
    expect(s.chips).toEqual(['US', 'S1', 'A']);
    expect(s.group).toBe('Weight');
    await page.click('#rm-reset');
    s = await state(page);
    expect(s.chips).toEqual([]);
    expect(s.group).toBe('All');
    expect(s.count).toBe('5 / 5 participants selected');
    expect(s.tiles).toEqual(['A', 'B', 'D', 'C', 'E']);
    expect(s.vitals.sort()).toEqual(['A weight', 'B pulse', 'D height', 'D weight']);
  });

  test('the settings panel switches the flag rule and every section follows (#343, #344)', async ({ page }) => {
    await expect(page.locator('#rm-settings')).toBeHidden();
    await page.click('#rm-settings-toggle');
    await expect(page.locator('#rm-settings')).toBeVisible();
    await expect(page.locator('#rm-settings-toggle')).toHaveAttribute('aria-expanded', 'true');
    await expect(page.locator('#rm-th-amber')).toHaveValue('2');
    await expect(page.locator('#rm-th-red')).toHaveValue('3');
    await expect(page.locator('#rm-min-windows')).toHaveValue('1');
    await expect(page.locator('[data-rm-unit="rm-th-red"]')).toHaveText('windows');

    let f = await flags(page);
    expect(f.tiles['A weight']).toBe('Amber');
    expect(f.tiles['B pulse']).toBe('Green');
    expect(f.listing['A weight']).toBe('Amber');
    expect(f.overview.weight).toEqual({ evaluable: 3, amber: 1, red: 0 });
    expect(f.rule[0]).toContain('repeating windows, Amber \u2265 2, Red \u2265 3; participants need 1 window for a flag');

    // % of windows, from the kri0020 thresholds.
    await page.click('[data-rm-set="rule"][value="rate"]');
    await expect(page.locator('#rm-th-amber')).toHaveValue('20');
    await expect(page.locator('#rm-th-red')).toHaveValue('30');
    await expect(page.locator('[data-rm-unit="rm-th-red"]')).toHaveText('%');
    f = await flags(page);
    expect([f.tiles['A weight'], f.tiles['B pulse'], f.tiles['D weight'], f.tiles['B weight']]).toEqual(['Red', 'Red', 'Amber', 'Green']);
    expect([f.listing['A weight'], f.listing['B pulse'], f.listing['D weight'], f.listing['D height']]).toEqual(['Red', 'Red', 'Amber', 'No KRI']);
    expect(f.overview.weight).toEqual({ evaluable: 3, amber: 1, red: 1 });
    expect(f.overview.pulse).toEqual({ evaluable: 2, amber: 0, red: 1 });
    expect(f.rule.every((t) => t.includes('% of windows that repeat, Amber \u2265 20%, Red \u2265 30%'))).toBe(true);
    // The bars count the recomputed flags.
    const red = await page.evaluate(() => {
      const c = document.getElementById('rm-country-pulse').gsmChart;
      return c.data.datasets.map((d) => d.label);
    });
    expect(red).toContain('Red');
    // The tiles CSV carries the recomputed flags.
    const csv = await downloadCsv(page, '#rm-tiles-csv');
    expect(csv).toContain('US,S1,B,pulse,Red,1,2,0.5');
  });

  test('flag thresholds and minimum windows are validated, applied and restored (#343, #344)', async ({ page }) => {
    await page.click('#rm-settings-toggle');
    await setInput(page, 'rm-th-amber', 5);
    await expect(page.locator('#rm-settings-msg')).toHaveText('Amber must not be above Red.');
    expect((await flags(page)).tiles['A weight']).toBe('Amber');

    await setInput(page, 'rm-th-amber', 1);
    await setInput(page, 'rm-th-red', 2);
    await expect(page.locator('#rm-settings-msg')).toHaveText('');
    let f = await flags(page);
    expect([f.tiles['A weight'], f.tiles['B pulse'], f.tiles['D weight']]).toEqual(['Red', 'Amber', 'Amber']);
    expect(f.overview.weight).toEqual({ evaluable: 3, amber: 1, red: 1 });

    // A weight and B pulse have 2 windows, D weight 4.
    await setInput(page, 'rm-min-windows', 3);
    f = await flags(page);
    expect([f.tiles['A weight'], f.tiles['B pulse'], f.tiles['D weight']]).toEqual(['Not evaluable', 'Not evaluable', 'Amber']);
    expect(f.overview.weight).toEqual({ evaluable: 1, amber: 1, red: 0 });
    expect(f.rule[0]).toContain('repeating windows, Amber \u2265 1, Red \u2265 2; participants need 3 windows for a flag');
    await expect(page.locator('#rm-tiles td.rm-tiles-c[data-subjid="A"]').first()).toHaveText('NE');
    await setInput(page, 'rm-min-windows', 0);
    await expect(page.locator('#rm-settings-msg')).toContainText('Minimum windows');

    await page.click('#rm-settings-defaults');
    await expect(page.locator('#rm-th-amber')).toHaveValue('2');
    await expect(page.locator('#rm-min-windows')).toHaveValue('1');
    await expect(page.locator('#rm-settings-msg')).toHaveText('');
    f = await flags(page);
    expect([f.tiles['A weight'], f.tiles['B pulse'], f.tiles['D weight']]).toEqual(['Amber', 'Green', 'Green']);
  });

  test('the contents button hides and restores the table of contents (#344)', async ({ page }) => {
    const btn = page.locator('#rm-toc-toggle');
    await expect(btn).toBeVisible();
    await expect(page.locator('#TOC')).toBeVisible();
    await btn.click();
    await expect(page.locator('#TOC')).toBeHidden();
    await expect(btn).toHaveText('Show contents');
    expect(await page.evaluate(() => document.body.classList.contains('rm-toc-hidden'))).toBe(true);
    await btn.click();
    await expect(page.locator('#TOC')).toBeVisible();
    await expect(btn).toHaveText('Hide contents');
  });
});

test.describe('Repeat Measurements blood pressure view', () => {
  let errors;
  test.beforeEach(async ({ page }) => {
    errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(BP);
    await page.waitForFunction(() => document.querySelectorAll('#rm-tiles tbody tr').length > 0);
  });
  test.afterEach(() => expect(errors).toEqual([]));

  const view = (page) => page.evaluate(() => {
    const api = (id) => jQuery('#' + id + ' table.dataTable').DataTable();
    const col = (id, name) => api(id).settings()[0].aoColumns.findIndex((c) => c.name === name);
    const bp = ['sysbp', 'diabp', 'bp'];
    const visible = (el) => !!el && el.offsetParent !== null;
    return {
      tiles: [...new Set(document.getElementById('rm-tiles').gsmChart.data.map((t) => t.vital))].filter((v) => bp.includes(v)),
      overview: Array.from(document.querySelectorAll('#rm-overview tr[data-rm-overview]')).map((tr) => tr.dataset.rmOverview).filter((v) => bp.includes(v)),
      listing: api('rm-vitals').rows({ search: 'applied' }).data().toArray()
        .map((r) => r[col('rm-vitals', 'vital')]).filter((v) => bp.includes(v)),
      wide: api('rm-dt-wide').settings()[0].aoColumns
        .filter((c, i) => bp.includes(c.name) && api('rm-dt-wide').column(i).visible()).map((c) => c.name),
      charts: bp.filter((v) => visible(document.querySelector('[data-rm-vital="' + v + '"]'))),
    };
  });

  test('blood pressure shows separately, combined or both, and paired BP has no KRI (#343, #344)', async ({ page }) => {
    // Unticking "only ... with a repeat window" lists every BP row.
    await page.uncheck('#rm-only-repeat');
    let v = await view(page);
    expect(v.tiles).toEqual(['sysbp', 'diabp']);
    expect(v.overview).toEqual(['sysbp', 'diabp']);
    expect(v.listing.sort()).toEqual(['diabp', 'diabp', 'diabp', 'diabp', 'diabp', 'sysbp', 'sysbp', 'sysbp', 'sysbp', 'sysbp']);
    expect(v.wide).toEqual(['sysbp', 'diabp']);

    await page.click('#rm-settings-toggle');
    await page.click('[data-rm-set="bp"][value="combined"]');
    v = await view(page);
    expect(v.tiles).toEqual(['bp']);
    expect(v.overview).toEqual(['bp']);
    expect(new Set(v.listing)).toEqual(new Set(['bp']));
    expect(v.wide).toEqual(['bp']);
    await expect(page.locator('#rm-overview tr[data-rm-overview="bp"]')).toContainText('none (paired SBP and DBP)');
    // A: 120/80 120/80 120/80 120/81 repeats in 1 of 2 windows.
    const tile = await page.evaluate(() => document.getElementById('rm-tiles').gsmChart.data.find((t) => t.subjid === 'A' && t.vital === 'bp'));
    expect([tile.Numerator, tile.Denominator, tile.flag]).toEqual([1, 2, 'Green']);
    await expect(page.locator('#rm-dt-wide tbody tr').first()).toContainText('120/80');

    await page.click('[data-rm-group="BP"]');
    v = await view(page);
    expect(v.tiles).toEqual(['bp']);

    await page.click('[data-rm-set="bp"][value="both"]');
    v = await view(page);
    expect(v.tiles).toEqual(['sysbp', 'diabp', 'bp']);
    expect(v.wide).toEqual(['sysbp', 'diabp', 'bp']);
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
