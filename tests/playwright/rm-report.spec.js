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
  const dt = (id) => jQuery('#' + id + ' table.dataTable').DataTable().rows({ search: 'applied' }).data().toArray();
  const vitalsApi = jQuery('#rm-vitals table.dataTable').DataTable();
  const col = (name) => vitalsApi.settings()[0].aoColumns.findIndex((c) => c.name === name);
  return {
    overview: document.querySelector('#rm-overview p').textContent,
    tiles: Array.from(document.querySelectorAll('#rm-tiles tbody tr th')).map((th) => th.textContent.trim()),
    tileColumns: [...new Set(document.getElementById('rm-tiles').gsmChart.data.map((t) => t.column))],
    vitals: dt('rm-vitals').map((r) => r[col('subjid')] + ' ' + r[col('vital')]),
    records: dt('rm-records').length,
    recordsShown: document.getElementById('rm-records-view').style.display !== 'none',
    compact: document.getElementById('rm-vitals-wrap').classList.contains('rm-compact'),
    chips: Array.from(document.querySelectorAll('.rm-chip'))
      .filter((c) => c.style.display !== 'none')
      .map((c) => c.querySelector('.rm-chip-value').textContent),
  };
});

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

  test('opens on the study with repeating vitals listed (#344, #346, #347)', async ({ page }) => {
    const s = await state(page);
    expect(s.overview).toBe('Study: 5 enrolled participants');
    expect(s.tiles).toEqual(['A', 'B', 'D', 'C', 'E']);
    expect(s.vitals.sort()).toEqual(['A weight', 'B pulse', 'D height', 'D weight']);
    expect(s.recordsShown).toBe(false);
    expect(s.compact).toBe(false);
    expect(s.chips).toEqual([]);
  });

  test('a vital group filters the charts, tiles and listing (#344)', async ({ page }) => {
    await page.click('[data-rm-group="HR"]');
    const s = await state(page);
    expect(s.tileColumns).toEqual(['HR']);
    expect(s.vitals).toEqual(['B pulse']);
    await expect(page.locator('[data-rm-vital="weight"]').first()).toBeHidden();
    await expect(page.locator('[data-rm-vital="pulse"]').first()).toBeAttached();
  });

  test('country and site bars filter every section and show chips (#344, #345)', async ({ page }) => {
    await clickBar(page, 'rm-country-weight', { GroupID: 'JP', Level: 'country' });
    let s = await state(page);
    expect(s.overview).toBe('JP: 2 enrolled participants');
    expect(s.tiles).toEqual(['D', 'E']);
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

  test('selecting a participant lists all of their vitals and clearing restores the listing (#346, #347)', async ({ page }) => {
    await page.locator('#rm-tiles tbody tr th', { hasText: /^A$/ }).click();
    let s = await state(page);
    expect(s.chips).toEqual(['A']);
    expect(s.overview).toBe('Participant A: 1 enrolled participant');
    expect(s.vitals).toHaveLength(7);
    expect(s.compact).toBe(true);
    await page.click('#rm-chip-subj button');
    s = await state(page);
    expect(s.vitals).toHaveLength(4);
    expect(s.compact).toBe(false);
  });

  test('a vital row drills into the participant records and back (#346)', async ({ page }) => {
    await page.locator('#rm-vitals tbody tr').first().locator('td').nth(2).click();
    let s = await state(page);
    expect(s.recordsShown).toBe(true);
    expect(s.records).toBe(4);
    await expect(page.locator('#rm-crumb')).toContainText('A');
    // A's four weights repeat; pulse (60, 61, 62) does not.
    await expect(page.locator('#rm-records tbody td.rw')).toHaveCount(4);
    await page.click('#rm-back');
    expect((await state(page)).recordsShown).toBe(false);

    await page.click('#rm-all-records');
    s = await state(page);
    expect(s.recordsShown).toBe(true);
    expect(s.records).toBe(16);
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
