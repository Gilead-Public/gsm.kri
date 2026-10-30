const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const FULL = 'file://' + path.resolve(__dirname, 'fixture', 'RM.html');
const DEGRADED = 'file://' + path.resolve(__dirname, 'fixture', 'RM_degraded.html');
const BP = 'file://' + path.resolve(__dirname, 'fixture', 'RM_bp.html');
const EDGE = 'file://' + path.resolve(__dirname, 'fixture', 'RM_edge.html');
const SPLIT = 'file://' + path.resolve(__dirname, 'fixture', 'RM_split.html');

// Facts of rm_Fixture() in tests/testthat/helper-rm.R (render-rm-fixture.R):
// A, B (US/S1), C (US/S2), D, E (JP/S3); repeating windows in A weight (2/2),
// B pulse (1/2), D weight (1/4) and D height (1/1). Under the default count
// rule (Amber 2, Red 3) only A weight is flagged, Amber. Height has no KRI but
// is flagged with the same rule.

// Clicks a country or site row of the Site/Country Distribution table.
async function clickDistRow(page, level, key) {
  await page.click('#rm-dist-' + level);
  await page.click('#rm-dist tbody tr[data-rm-dist-row="' + level + '"][data-rm-dist-key="' + key + '"] td.rm-stick');
}

// The Site/Country Distribution table: row keys, measure columns and each
// cell's N / Amber / Red (or site flag dot) by "row vital".
const dist = (page) => page.evaluate(() => {
  const el = document.getElementById('rm-dist');
  const cells = {};
  el.querySelectorAll('tbody tr').forEach((tr) => {
    const key = tr.dataset.rmDistKey || 'Study';
    tr.querySelectorAll('td[data-rm-dist-vital]').forEach((td) => {
      const dot = td.querySelector('.rm-sf');
      cells[key + ' ' + td.dataset.rmDistVital] = {
        n: +td.dataset.rmN,
        amber: +td.dataset.rmAmber,
        red: +td.dataset.rmRed,
        dot: dot ? dot.dataset.rmSiteFlag + (dot.classList.contains('rm-o') ? ' calculated' : ' KRI') : null,
      };
    });
  });
  return {
    level: el.querySelector('table').dataset.rmDistLevel,
    unit: el.querySelector('table').dataset.rmDistUnit,
    rows: Array.from(el.querySelectorAll('tbody tr[data-rm-dist-key]')).map((tr) => tr.dataset.rmDistKey),
    on: Array.from(el.querySelectorAll('tbody tr.rm-on')).map((tr) => tr.dataset.rmDistKey),
    dim: el.querySelectorAll('tbody tr.rm-dim').length,
    measures: Array.from(el.querySelectorAll('th.rm-grp[data-rm-dist-sort]')).map((th) => th.dataset.rmDistSort),
    headRows: el.querySelectorAll('thead tr').length,
    sortTitle: el.querySelector('th.rm-grp[data-rm-dist-sort]').title,
    sort: Array.from(el.querySelectorAll('th[aria-sort]')).map((th) => th.dataset.rmDistSort + ' ' + th.getAttribute('aria-sort')),
    count: document.getElementById('rm-dist-count').textContent,
    counts: Object.fromEntries(Array.from(el.querySelectorAll('tbody tr')).map((tr) => [
      tr.dataset.rmDistKey || 'Study',
      [tr.querySelector('[data-rm-dist-np]'), tr.querySelector('[data-rm-dist-ns]')].map((td) => (td ? +td.textContent : null)),
    ])),
    lead: Array.from(el.querySelectorAll('thead tr:first-child th:not(.rm-grp)')).map((th) => th.lastChild.nodeType === 3 && th.classList.contains('rm-cnt') ? th.lastChild.textContent : th.firstChild.textContent),
    cells,
  };
});

// Shows only the given vitals through the Vitals multi-select.
async function pickVitals(page, vitals) {
  await page.click('#rm-vital-btn');
  await page.uncheck('#rm-vital-all');
  for (const v of vitals) await page.check('[data-rm-vital-cb][value="' + v + '"]');
  await page.keyboard.press('Escape');
}

const state = (page) => page.evaluate(() => {
  const api = (id) => jQuery('#' + id + ' table.dataTable').DataTable();
  const col = (id, name) => api(id).settings()[0].aoColumns.findIndex((c) => c.name === name);
  const rows = (id) => api(id).rows({ search: 'applied' }).data().toArray();
  const shown = (id) => document.getElementById(id).closest('[data-rm-shape-view]').style.display !== 'none';
  return {
    overview: document.querySelector('#rm-overview tbody').textContent,
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
    vitalSummary: document.getElementById('rm-vital-summary').textContent,
  };
});

// Participant flags by "subjid vital" from the tiles, the listing and the overview.
const flags = (page) => page.evaluate(() => {
  // The flag counts are in the Counts view; the filters do not change the overview.
  // The click closes an open Settings popover, so reopen it.
  const open = !document.getElementById('rm-settings').hidden;
  document.getElementById('rm-ov-counts').click();
  if (open) document.getElementById('rm-settings-toggle').click();
  const api = jQuery('#rm-vitals table.dataTable').DataTable();
  const cols = api.settings()[0].aoColumns;
  const col = (name) => cols.findIndex((c) => c.name === name);
  const tiles = {};
  document.getElementById('rm-tiles').gsmChart.data.forEach((t) => { tiles[t.subjid + ' ' + t.vital] = t.flag; });
  const listing = {};
  api.rows().data().toArray().forEach((r) => { listing[r[col('subjid')] + ' ' + r[col('vital')]] = r[col('flag')]; });
  const overview = {};
  document.querySelectorAll('#rm-overview tr[data-rm-overview]').forEach((tr) => {
    const n = (col) => tr.querySelector('[data-rm-col="' + col + '"]');
    const fl = Array.from(n('participant-flags').querySelectorAll('.rm-fl')).map((s) => +s.textContent);
    overview[tr.dataset.rmOverview] = { evaluable: parseInt(n('participants').textContent, 10), amber: fl[0], red: fl[1] };
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
    expect(s.vitalSummary).toBe('All');
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

  test('the study overview lists every measure with site and participant flags for the whole study (#344)', async ({ page }) => {
    await page.locator('#rm-ov-counts').click();
    const rows = await page.evaluate(() => Array.from(document.querySelectorAll('#rm-overview tr[data-rm-overview]')).map((tr) => {
      const n = (col) => tr.querySelector('[data-rm-col="' + col + '"]');
      return {
        vital: tr.dataset.rmOverview,
        kri: (tr.querySelector('.rm-kri') || {}).title || null,
        sites: n('sites').textContent,
        siteSource: n('site-flags').dataset.rmSource,
        siteFilled: n('site-flags').querySelectorAll('.rm-dot:not(.rm-o)').length,
        siteFlags: Array.from(n('site-flags').querySelectorAll('.rm-fl')).map((x) => x.textContent),
        participants: n('participants').textContent,
        participantEmpty: n('participant-flags').querySelectorAll('.rm-dot.rm-o').length,
        participantFlags: Array.from(n('participant-flags').querySelectorAll('.rm-fl')).map((x) => x.textContent),
      };
    }));
    expect(rows.map((r) => r.vital)).toEqual(['weight', 'pulse', 'sysbp', 'diabp', 'resp', 'temp', 'height']);
    const w = rows[0];
    // Weight: KRI site flags S1 Red, S2 Green, S3 Amber (filled); A Amber.
    expect([w.kri, w.sites, w.siteSource, w.siteFilled, w.siteFlags]).toEqual(['kri0020a', '3 / 3', 'KRI', 2, ['1', '1']]);
    expect([w.participants, w.participantEmpty, w.participantFlags]).toEqual(['3 / 5', 2, ['1', '0']]);
    const h = rows[6];
    // Height has no KRI: report-calculated site flags (empty), none above accrual.
    expect([h.kri, h.sites, h.siteSource, h.siteFilled]).toEqual([null, '0 / 3', 'report', 0]);
    expect(h.participants).toBe('1 / 5');
    for (const label of ['Sites', 'Participants']) {
      await expect(page.locator('#rm-overview thead th', { hasText: label }).locator('.rm-info')).toHaveAttribute('title', /flag/);
    }
    await expect(page.locator('#rm-overview .rm-info').first()).toHaveAttribute('title', /Amber \u2265 20%, Red \u2265 30%; sites need 3 windows/);
    // Filters do not change the overview.
    const before = (await state(page)).overview;
    await clickDistRow(page, 'country', 'JP');
    await pickVitals(page, ['pulse']);
    expect((await state(page)).overview).toBe(before);
  });

  test('the study overview opens as distribution bars and switches to counts (#344)', async ({ page }) => {
    await expect(page.locator('#rm-ov-distribution')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('#rm-ov-counts')).toHaveAttribute('aria-pressed', 'false');
    await expect(page.locator('#rm-overview [data-rm-ov-view="distribution"]')).toHaveCount(1);
    const bars = await page.evaluate(() => Array.from(document.querySelectorAll('#rm-overview tr[data-rm-overview]')).map((tr) => {
      const parts = (col) => {
        const cell = tr.querySelector('[data-rm-col="' + col + '"]');
        const out = {};
        cell.querySelectorAll('[data-rm-part]').forEach((x) => {
          out[x.dataset.rmPart] = Math.round(parseFloat(x.style.width));
        });
        return { parts: out, n: (cell.querySelector('.rm-bar-n') || {}).textContent || null, text: cell.textContent, title: (cell.querySelector('.rm-bar') || {}).title || '' };
      };
      return { vital: tr.dataset.rmOverview, site: parts('site-dist'), part: parts('participant-dist') };
    }));
    expect(bars.map((b) => b.vital)).toEqual(['weight', 'pulse', 'sysbp', 'diabp', 'resp', 'temp', 'height']);
    // Weight: sites S1 Red, S2 Green, S3 Amber; participants A Amber of 3 evaluable.
    expect([bars[0].site.parts, bars[0].site.n]).toEqual([{ none: 33, amber: 33, red: 33 }, '3']);
    expect(bars[0].site.title).toMatch(/Red: 1 \(33%\).*of 3 sites evaluated.*from kri0020a/);
    expect([bars[0].part.parts, bars[0].part.n]).toEqual([{ none: 67, amber: 33 }, '3']);
    // Height: no site reaches the accrual, so the site bar is not drawn.
    expect([bars[6].site.parts, bars[6].site.text]).toEqual([{}, 'Not evaluated']);
    // Filters do not change it.
    const before = await page.locator('#rm-overview tbody').innerHTML();
    await clickDistRow(page, 'country', 'JP');
    expect(await page.locator('#rm-overview tbody').innerHTML()).toBe(before);
    await page.locator('#rm-ov-counts').click();
    await expect(page.locator('#rm-ov-counts')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('#rm-overview [data-rm-ov-view="counts"]')).toHaveCount(1);
    await page.locator('#rm-ov-distribution').click();
    await expect(page.locator('#rm-overview [data-rm-ov-view="distribution"]')).toHaveCount(1);
  });

  test('clicking a study overview measure selects it in the Measures select, and again selects all (#344)', async ({ page }) => {
    await expect(page.locator('.rm-eyebrow')).toHaveText('Measures');
    const picked = () => page.locator('[data-rm-vital-cb]').evaluateAll((els) => els.filter((e) => e.checked).map((e) => e.value));
    const row = (v) => page.locator('#rm-overview tbody tr[data-rm-overview="' + v + '"] td').first();
    const distCols = () => page.locator('#rm-dist th.rm-grp[data-rm-dist-sort]').evaluateAll((els) => els.map((e) => e.dataset.rmDistSort));
    await row('weight').click();
    expect(await picked()).toEqual(['weight']);
    expect(await distCols()).toEqual(['weight']);
    await expect(page.locator('#rm-overview tr[data-rm-overview="weight"]')).toHaveClass(/rm-on/);
    await expect(page.locator('#rm-overview tr[data-rm-overview="pulse"]')).toHaveClass(/rm-dim/);
    // The Counts view picks the same way; another row replaces the selection.
    await page.locator('#rm-ov-counts').click();
    await row('pulse').click();
    expect(await picked()).toEqual(['pulse']);
    await row('pulse').click();
    expect((await picked()).length).toBe(7);
    await expect(page.locator('#rm-overview tr.rm-on, #rm-overview tr.rm-dim')).toHaveCount(0);
  });

  test('the Measures multi-select filters the distribution, tiles and listing (#344)', async ({ page }) => {
    const opts = await page.locator('[data-rm-vital-cb]').evaluateAll((els) => els.map((e) => e.value));
    expect(opts).toEqual(['weight', 'pulse', 'sysbp', 'diabp', 'resp', 'temp', 'height']);
    await page.click('#rm-vital-btn');
    await expect(page.locator('#rm-vital-menu')).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.locator('#rm-vital-menu')).toBeHidden();
    await pickVitals(page, ['pulse']);
    let s = await state(page);
    expect(s.vitalSummary).toBe('HR');
    expect(s.tileColumns).toEqual(['HR']);
    expect(s.vitals).toEqual(['B pulse']);
    expect(s.wideVitals).toEqual(['pulse']);
    expect([...new Set(s.wide)]).toEqual(['B']);
    expect((await dist(page)).measures).toEqual(['pulse']);
    // A vital without a KRI can be picked like any other.
    await page.click('#rm-vital-btn');
    await page.check('[data-rm-vital-cb][value="height"]');
    await page.click('h1');
    await expect(page.locator('#rm-vital-menu')).toBeHidden();
    s = await state(page);
    expect(s.vitalSummary).toBe('HR, Ht');
    expect(s.tileColumns).toEqual(['HR', 'Ht']);
    expect(s.vitals.sort()).toEqual(['B pulse', 'D height']);
    expect((await dist(page)).measures).toEqual(['pulse', 'height']);
    await page.click('#rm-vital-btn');
    await page.uncheck('[data-rm-vital-cb][value="pulse"]');
    await page.uncheck('[data-rm-vital-cb][value="height"]');
    await expect(page.locator('#rm-dist')).toHaveText('No vitals selected.');
  });

  test('the Site/Country Distribution shows participant flags by measure for each country, with a Study row matching the overview (#345)', async ({ page }) => {
    let d = await dist(page);
    expect([d.level, d.unit]).toEqual(['country', 'participants']);
    expect(d.measures).toEqual(['weight', 'pulse', 'sysbp', 'diabp', 'resp', 'temp', 'height']);
    // One header row; the Cells toggle (and the header hover) says what the bars count.
    expect(d.headRows).toBe(1);
    expect(d.sortTitle).toBe('Participant flags. Sort by % participants flagged');
    expect(d.rows).toEqual(['JP', 'US']);
    expect(d.count).toBe('2 countries');
    // Enrolled participants and sites per row.
    expect(d.lead).toEqual(['Country', 'Participants', 'Sites']);
    expect(d.counts).toEqual({ Study: [5, 3], JP: [2, 1], US: [3, 2] });
    // A (US) is the only flag: Amber weight.
    expect(d.cells['US weight']).toEqual({ n: 2, amber: 1, red: 0, dot: null });
    expect(d.cells['JP weight']).toEqual({ n: 1, amber: 0, red: 0, dot: null });
    expect(d.cells['JP height']).toEqual({ n: 1, amber: 0, red: 0, dot: null });
    const f = await flags(page);
    for (const v of d.measures) {
      const c = d.cells['Study ' + v];
      expect({ evaluable: c.n, amber: c.amber, red: c.red }, v).toEqual(f.overview[v]);
    }
    await expect(page.locator('#rm-dist tr[data-rm-dist-key="US"] td[data-rm-dist-vital="weight"] [data-rm-part]')).toHaveCount(2);
    await expect(page.locator('#rm-dist tr[data-rm-dist-key="JP"] td[data-rm-dist-vital="pulse"]')).toHaveText('Not evaluated');
    await expect(page.locator('#rm-dist thead th.rm-stick .rm-info')).toHaveAttribute('title', /Participant flag: repeating windows, Amber \u2265 2, Red \u2265 3/);
    // The hover card has the counts.
    await page.hover('#rm-dist tr[data-rm-dist-key="US"] td[data-rm-dist-vital="weight"]');
    const tip = page.locator('#rm-dist-tip');
    await expect(tip).toBeVisible();
    await expect(tip).toContainText('US \u00b7 Weight \u00b7 participants');
    await expect(tip).toContainText('Evaluable: 2 / 3 (67%)');
    await expect(tip).toContainText('1 flagged (50%)');
    await page.hover('h1');
    await expect(tip).toBeHidden();

    // Site flags by country: S1 Red, S2 Green (US); S3 Amber (JP).
    await page.click('#rm-dist-sites');
    d = await dist(page);
    expect([d.unit, d.sortTitle]).toEqual(['sites', 'Site flags. Sort by % sites flagged']);
    expect(d.cells['US weight']).toEqual({ n: 2, amber: 0, red: 1, dot: null });
    expect(d.cells['JP weight']).toEqual({ n: 1, amber: 1, red: 0, dot: null });
    expect(d.cells['Study weight']).toEqual({ n: 3, amber: 1, red: 1, dot: null });
    // Height: calculated in the report, no site reaches the accrual.
    expect(d.cells['Study height'].n).toBe(0);
    await expect(page.locator('#rm-dist thead th.rm-stick .rm-info')).toHaveAttribute('title', /Site flag: .*Amber \u2265 20%, Red \u2265 30%/);
    await page.hover('#rm-dist tr[data-rm-dist-key="US"] td[data-rm-dist-vital="weight"]');
    await expect(tip).toContainText('KRI site flags (kri0020a)');
    await expect(tip).toContainText('Sites evaluated: 2 / 2 (100%)');
  });

  test('the Site/Country Distribution by site shows each site flag, searches and disables site-flag cells (#345)', async ({ page }) => {
    await page.click('#rm-dist-sites');
    await page.click('#rm-dist-site');
    await expect(page.locator('#rm-dist-sites')).toBeDisabled();
    await expect(page.locator('#rm-dist-participants')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('#rm-dist-search')).toBeVisible();
    let d = await dist(page);
    expect([d.level, d.unit]).toEqual(['site', 'participants']);
    // By country, then site.
    expect(d.rows).toEqual(['S3', 'S1', 'S2']);
    expect(d.count).toBe('3 of 3 sites');
    expect(d.lead).toEqual(['Site', 'Country', 'Participants']);
    expect(d.counts).toEqual({ Study: [5, null], S3: [2, null], S1: [2, null], S2: [1, null] });
    await expect(page.locator('#rm-dist tr[data-rm-dist-key="S1"] td.rm-stick2')).toHaveText('US');
    expect(d.cells['S1 weight']).toEqual({ n: 2, amber: 1, red: 0, dot: 'Red KRI' });
    expect(d.cells['S3 weight'].dot).toBe('Amber KRI');
    expect(d.cells['S2 weight'].dot).toBe('Green KRI');
    expect(d.cells['S1 height'].dot).toBe('Not evaluated calculated');
    expect(d.cells['Study weight'].dot).toBe(null);
    await page.hover('#rm-dist tr[data-rm-dist-key="S1"] td[data-rm-dist-vital="weight"]');
    await expect(page.locator('#rm-dist-tip')).toContainText('Site flag: Red \u00b7 2 of 4 windows repeat (50%) \u00b7 kri0020a');

    await page.fill('#rm-dist-search', 's2');
    d = await dist(page);
    expect([d.rows, d.count]).toEqual([['S2'], '1 of 3 sites']);
    await page.fill('#rm-dist-search', 'jp');
    expect((await dist(page)).rows).toEqual(['S3']);
    await page.fill('#rm-dist-search', '');

    await page.click('#rm-dist-country');
    await expect(page.locator('#rm-dist-sites')).toBeEnabled();
    await expect(page.locator('#rm-dist-search')).toBeHidden();
  });

  test('clicking a measure sorts the distribution rows by % flagged (#345)', async ({ page }) => {
    const weight = page.locator('#rm-dist th[data-rm-dist-sort="weight"]');
    await weight.click();
    let d = await dist(page);
    // US: 1 of 2 flagged; JP: 0 of 1.
    expect([d.rows, d.sort]).toEqual([['US', 'JP'], ['weight descending']]);
    expect(d.count).toBe('2 countries \u00b7 sorted by % flagged, Weight');
    await weight.click();
    d = await dist(page);
    expect([d.rows, d.sort]).toEqual([['JP', 'US'], ['weight ascending']]);
    await weight.click();
    d = await dist(page);
    expect([d.rows, d.sort, d.count]).toEqual([['JP', 'US'], [], '2 countries']);
    // By site: S1 50%, S3 0%, S2 not evaluated.
    await page.click('#rm-dist-site');
    await weight.click();
    expect((await dist(page)).rows).toEqual(['S1', 'S3', 'S2']);
  });

  test('clicking Participants or Sites sorts the distribution rows by count (#345)', async ({ page }) => {
    const np = page.locator('#rm-dist th[data-rm-dist-sort="_np"]');
    const ns = page.locator('#rm-dist th[data-rm-dist-sort="_ns"]');
    // US: 3 participants at 2 sites; JP: 2 at 1. Default order is by name.
    await np.click();
    let d = await dist(page);
    expect([d.rows, d.sort, d.count]).toEqual([['US', 'JP'], ['_np descending'], '2 countries \u00b7 sorted by participants']);
    await np.click();
    expect((await dist(page)).rows).toEqual(['JP', 'US']);
    await ns.click();
    d = await dist(page);
    expect([d.rows, d.sort, d.count]).toEqual([['US', 'JP'], ['_ns descending'], '2 countries \u00b7 sorted by sites']);
    // Site view has no Sites column, so its sort clears; Participants still sorts.
    await page.click('#rm-dist-site');
    d = await dist(page);
    // Unsorted site rows run by country (JP first), then site.
    expect([d.rows, d.sort]).toEqual([['S3', 'S1', 'S2'], []]);
    await np.click();
    expect((await dist(page)).rows).toEqual(['S1', 'S3', 'S2']);
  });

  test('the Flags control keeps the rows with an Amber or Red flag in any shown measure (#345)', async ({ page }) => {
    // Expected rows, from the cells' own counts.
    const expected = (red) => page.evaluate((red) => Array.from(document.querySelectorAll('#rm-dist tbody tr[data-rm-dist-key]'))
      .filter((tr) => Array.from(tr.querySelectorAll('td[data-rm-amber]')).some((td) => (red ? 0 : +td.dataset.rmAmber) + +td.dataset.rmRed > 0))
      .map((tr) => tr.dataset.rmDistKey), red);
    for (const level of ['country', 'site']) {
      await page.click('#rm-dist-' + level);
      await page.click('#rm-dist-all');
      const all = (await dist(page)).rows;
      const anyRows = await expected(false);
      const redRows = await expected(true);
      expect(anyRows.length).toBeLessThan(all.length);
      await page.click('#rm-dist-any');
      await expect(page.locator('#rm-dist-any')).toHaveAttribute('aria-pressed', 'true');
      expect((await dist(page)).rows).toEqual(anyRows);
      await page.click('#rm-dist-red');
      expect((await dist(page)).rows).toEqual(redRows);
    }
    // The Study row stays, and the count says how many rows are kept.
    await page.click('#rm-dist-country');
    await page.click('#rm-dist-any');
    await expect(page.locator('#rm-dist tr.rm-study')).toHaveCount(1);
    const d = await dist(page);
    expect(d.count).toBe(d.rows.length + ' of 2 countries');
  });

  test('distribution rows filter every section and show chips (#344, #345)', async ({ page }) => {
    await clickDistRow(page, 'country', 'JP');
    let s = await state(page);
    expect(s.count).toBe('2 / 5 participants selected');
    expect(s.tiles).toEqual(['D', 'E']);
    expect([...new Set(s.wide)]).toEqual(['D']);
    expect(s.vitals.sort()).toEqual(['D height', 'D weight']);
    expect(s.chips).toEqual(['JP']);
    let d = await dist(page);
    expect([d.on, d.dim]).toEqual([['JP'], 1]);

    // Site rows narrow to the selected country.
    await clickDistRow(page, 'site', 'S3');
    d = await dist(page);
    expect([d.rows, d.on, d.count]).toEqual([['S3'], ['S3'], '1 of 3 sites']);
    s = await state(page);
    expect(s.chips).toEqual(['JP', 'S3']);
    // Click again to clear the site.
    await page.click('#rm-dist tr[data-rm-dist-key="S3"] td.rm-stick');
    expect((await state(page)).chips).toEqual(['JP']);

    await page.click('#rm-chip-country button');
    expect((await dist(page)).rows).toEqual(['S3', 'S1', 'S2']);
    await page.click('#rm-dist tr[data-rm-dist-key="S1"] td.rm-stick');
    s = await state(page);
    expect(s.tiles).toEqual(['A', 'B']);
    expect(s.chips).toEqual(['US', 'S1']);
    await page.click('#rm-chip-site button');
    await page.click('#rm-chip-country button');
    expect((await state(page)).tiles).toHaveLength(5);
    d = await dist(page);
    expect([d.on, d.dim]).toEqual([[], 0]);
  });

  test('every filter chip stays visible in the toolbar when all three are set (#344)', async ({ page }) => {
    await page.setViewportSize({ width: 1000, height: 800 });
    await page.click('#rm-dist-site');
    await clickDistRow(page, 'site', 'S1');
    await page.uncheck('#rm-only-repeat');
    await page.locator('#rm-vitals tbody tr').first().click();
    expect((await state(page)).chips).toHaveLength(3);
    const boxes = await page.evaluate(() => {
      const strip = document.getElementById('rm-filter-strip').getBoundingClientRect();
      return Array.from(document.querySelectorAll('.rm-chip')).filter((c) => c.offsetParent).map((c) => {
        const r = c.getBoundingClientRect();
        return r.left >= strip.left && r.right <= strip.right && r.top >= strip.top && r.bottom <= strip.bottom;
      });
    });
    expect(boxes).toEqual([true, true, true]);
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
    // D and E, one row per vital including height.
    expect(lines).toHaveLength(1 + 2 * 7);
  });

  test('a participant label or tile click filters the report and a second click clears it (#346, #347)', async ({ page }) => {
    await page.locator('#rm-tiles td.rm-tiles-c[data-subjid="A"]').first().click();
    let s = await state(page);
    expect(s.chips).toEqual(['A']);
    expect(s.count).toBe('1 / 5 participants selected');
    expect(s.selectedTile).toEqual(['A']);
    expect(s.vitals).toHaveLength(7);
    expect(s.compact).toBe(true);
    expect(s.dtOnly).toBe(false);
    expect(s.wide).toEqual(['A', 'A', 'A', 'A']);
    // The listing scopes to A and never gains columns or nested rows.
    // Participant + seven vitals (height included).
    await expect(page.locator('#rm-tiles thead th')).toHaveCount(8);
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
    expect(longCsv[1]).toMatch(/^"US","S1","A","Weight","kri0020a",/);
    // Long shows the metric as a KRI badge and shortens the repeat header.
    const longHead = await page.locator('#rm-dt-long thead th').allTextContents();
    expect(longHead).toEqual(['Country', 'Site', 'Participant', 'Vital', '#', 'Visit', 'Date', 'Value', 'Repeat']);
    await expect(page.locator('#rm-dt-long tbody tr').first().locator('.rm-kri')).toHaveAttribute('title', 'kri0020a');

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

    // Wide abbreviates vital headers, folds country into the site and greys
    // records not performed. Vitals without values in the rows are hidden.
    const wideHead = await page.locator('#rm-dt-wide thead th').evaluateAll((ths) => ths.map((th) => [th.textContent, th.title]));
    expect(wideHead.map((h) => h[0])).toEqual(['Site', 'Participant', 'Visit', 'Date', 'WT', 'HR', 'Ht']);
    expect(wideHead[4][1]).toBe('Weight (kri0020a)');
    expect(wideHead[6][1]).toBe('Height (no KRI)');
    await expect(page.locator('#rm-dt-wide tbody tr').first().locator('td').first().locator('span')).toHaveAttribute('title', 'US');

    await pickVitals(page, ['pulse']);
    const wideCsv = await downloadCsv(page, '#rm-dt-wide .buttons-csv');
    expect(wideCsv[0]).toBe('"Country","Site","Participant","Visit","Date","Performed","Heart rate","pulse_in_repeat_window"');
    expect(wideCsv).toHaveLength(1 + 4);
  });

  test('the data table fits its column without horizontal scrolling (#346)', async ({ page }) => {
    for (const shape of ['wide', 'long']) {
      await page.click('[data-rm-shape="' + shape + '"]');
      const fit = await page.evaluate((id) => {
        const wrap = document.querySelector('#' + id + ' .dataTables_wrapper') || document.getElementById(id);
        const table = wrap.querySelector('table.dataTable');
        return { table: table.scrollWidth, wrap: wrap.clientWidth };
      }, 'rm-dt-' + shape);
      expect(fit.table, shape).toBeLessThanOrEqual(fit.wrap + 1);
    }
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

  test('reset filters clears the vitals, country, site and participant (#344)', async ({ page }) => {
    await pickVitals(page, ['weight']);
    await clickDistRow(page, 'site', 'S1');
    await page.locator('#rm-tiles th[data-subjid="A"]').click();
    let s = await state(page);
    expect(s.chips).toEqual(['US', 'S1', 'A']);
    expect(s.vitalSummary).toBe('WT');
    await page.click('#rm-reset');
    s = await state(page);
    expect(s.chips).toEqual([]);
    expect(s.vitalSummary).toBe('All');
    await expect(page.locator('[data-rm-vital-cb]:not(:checked)')).toHaveCount(0);
    expect(s.count).toBe('5 / 5 participants selected');
    expect(s.tiles).toEqual(['A', 'B', 'D', 'C', 'E']);
    expect(s.vitals.sort()).toEqual(['A weight', 'B pulse', 'D height', 'D weight']);
  });

  test('the settings panel switches the flag rule and participant flags in every section follow (#343, #344)', async ({ page }) => {
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
    expect([f.listing['A weight'], f.listing['B pulse'], f.listing['D weight'], f.listing['D height']]).toEqual(['Red', 'Red', 'Amber', 'Red']);
    expect(f.overview.weight).toEqual({ evaluable: 3, amber: 1, red: 1 });
    expect(f.overview.pulse).toEqual({ evaluable: 2, amber: 0, red: 1 });
    expect(f.rule.every((t) => t.includes('% of windows that repeat, Amber \u2265 20%, Red \u2265 30%'))).toBe(true);
    // The distribution counts the recomputed flags.
    const d = await dist(page);
    expect(d.cells['US pulse']).toEqual({ n: 2, amber: 0, red: 1, dot: null });
    expect(d.cells['Study weight']).toEqual({ n: 3, amber: 1, red: 1, dot: null });
    await expect(page.locator('#rm-dist thead th.rm-stick .rm-info')).toHaveAttribute('title', /% of windows that repeat, Amber \u2265 20%, Red \u2265 30%/);
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
    await expect(page.locator('#TOC')).toHaveClass(/rm-toc/);
    // The sidebar's own button hides it too; the toolbar button brings it back.
    await expect(page.locator('#TOC .rm-toc-head')).toContainText('On this page');
    await page.click('#rm-toc-hide');
    await expect(page.locator('#TOC')).toBeHidden();
    await expect(btn).toHaveText('Show contents');
    await expect(btn).toBeFocused();
    await btn.click();
    await expect(page.locator('#rm-toc-hide')).toBeVisible();
    // The title card is not in the contents list.
    await expect(page.locator('#TOC')).not.toContainText('Repeat Measurements');
  });

  test('the header card reveals how to read the report, and settings close on Done, Esc or a click outside (#344)', async ({ page }) => {
    const how = page.locator('#rm-how');
    await expect(how).toBeHidden();
    await page.click('#rm-how-toggle');
    await expect(how).toBeVisible();
    await expect(how.locator('.rm-rule-text')).toContainText('Amber \u2265 2, Red \u2265 3');
    await expect(page.locator('#rm-how-toggle')).toHaveAttribute('aria-expanded', 'true');
    await page.click('#rm-how-toggle');
    await expect(how).toBeHidden();

    const panel = page.locator('#rm-settings');
    const toggle = page.locator('#rm-settings-toggle');
    await toggle.click();
    await expect(panel).toBeVisible();
    // The popover floats over the page instead of pushing it down.
    expect(await panel.evaluate((el) => getComputedStyle(el).position)).toBe('absolute');
    await page.click('#rm-settings-done');
    await expect(panel).toBeHidden();
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');

    await toggle.click();
    await page.keyboard.press('Escape');
    await expect(panel).toBeHidden();
    await expect(toggle).toBeFocused();

    await toggle.click();
    await page.click('[data-rm-set="rule"][value="rate"]');
    await expect(panel).toBeVisible();
    await page.click('h1');
    await expect(panel).toBeHidden();
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');
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
    return {
      tiles: [...new Set(document.getElementById('rm-tiles').gsmChart.data.map((t) => t.vital))].filter((v) => bp.includes(v)),
      overview: Array.from(document.querySelectorAll('#rm-overview tr[data-rm-overview]')).map((tr) => tr.dataset.rmOverview).filter((v) => bp.includes(v)),
      listing: api('rm-vitals').rows({ search: 'applied' }).data().toArray()
        .map((r) => r[col('rm-vitals', 'vital')]).filter((v) => bp.includes(v)),
      wide: api('rm-dt-wide').settings()[0].aoColumns
        .filter((c, i) => bp.includes(c.name) && api('rm-dt-wide').column(i).visible()).map((c) => c.name),
      dist: Array.from(document.querySelectorAll('#rm-dist th[data-rm-dist-sort]')).map((th) => th.dataset.rmDistSort).filter((v) => bp.includes(v)),
    };
  });

  test('blood pressure shows separately, combined or both, and paired BP is flagged without a KRI (#343, #344)', async ({ page }) => {
    // Unticking "only ... with a repeat window" lists every BP row.
    await page.uncheck('#rm-only-repeat');
    let v = await view(page);
    expect(v.tiles).toEqual(['sysbp', 'diabp']);
    expect(v.overview).toEqual(['sysbp', 'diabp']);
    expect(v.dist).toEqual(['sysbp', 'diabp']);
    expect(v.listing.sort()).toEqual(['diabp', 'diabp', 'diabp', 'diabp', 'diabp', 'sysbp', 'sysbp', 'sysbp', 'sysbp', 'sysbp']);
    expect(v.wide).toEqual(['sysbp', 'diabp']);

    await page.click('#rm-settings-toggle');
    await page.click('[data-rm-set="bp"][value="combined"]');
    v = await view(page);
    expect(v.tiles).toEqual(['bp']);
    expect(v.overview).toEqual(['bp']);
    expect(v.dist).toEqual(['bp']);
    await expect(page.locator('#rm-dist th[data-rm-dist-sort="bp"] .rm-kri')).toHaveCount(0);
    expect(new Set(v.listing)).toEqual(new Set(['bp']));
    expect(v.wide).toEqual(['bp']);
    await page.locator('#rm-ov-counts').click();
    const bpRow = page.locator('#rm-overview tr[data-rm-overview="bp"]');
    await expect(bpRow).toContainText('Blood pressure');
    await expect(bpRow.locator('.rm-kri')).toHaveCount(0);
    await expect(bpRow.locator('[data-rm-source="report"]')).toHaveCount(1);
    const opts = await page.locator('[data-rm-vital-opt]').evaluateAll((els) => els.filter((e) => e.style.display !== 'none').map((e) => e.dataset.rmVitalOpt));
    expect(opts).toContain('bp');
    expect(opts).not.toContain('sysbp');
    // A: 120/80 120/80 120/80 120/81 repeats in 1 of 2 windows.
    const tile = await page.evaluate(() => document.getElementById('rm-tiles').gsmChart.data.find((t) => t.subjid === 'A' && t.vital === 'bp'));
    expect([tile.Numerator, tile.Denominator, tile.flag]).toEqual([1, 2, 'Green']);
    await expect(page.locator('#rm-dt-wide tbody tr').first()).toContainText('120/80');

    await page.click('#rm-settings-toggle');
    await pickVitals(page, ['bp']);
    v = await view(page);
    expect(v.tiles).toEqual(['bp']);

    await page.click('#rm-settings-toggle');
    await page.click('[data-rm-set="bp"][value="both"]');
    v = await view(page);
    expect(v.tiles).toEqual(['sysbp', 'diabp', 'bp']);
    expect(v.wide).toEqual(['sysbp', 'diabp', 'bp']);
    expect(v.dist).toEqual(['sysbp', 'diabp', 'bp']);
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

// rm_FixtureEdge(): F (no country, S4) repeats in 2 of 3 weight windows; G's
// country (S5) holds quotes. Rate rule, Amber 0.5, Red 2/3.
test.describe('Repeat Measurements edge cases', () => {
  let errors;
  const COUNTRY = 'X" data-x="1 \'q\'';
  test.beforeEach(async ({ page }) => {
    errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(EDGE);
    await page.waitForFunction(() => document.querySelectorAll('#rm-tiles tbody tr').length > 0);
  });
  test.afterEach(() => expect(errors).toEqual([]));

  test('a 2/3 rate at a 2/3 threshold is Red in R and in the browser (#343)', async ({ page }) => {
    const f = await flags(page);
    expect(f.tiles['F weight']).toBe('Red');
    expect(f.listing['F weight']).toBe('Red');
    expect(f.overview.weight.red).toBe(1);
  });

  test('a country with quotes stays text in every title (#346)', async ({ page }) => {
    await page.uncheck('#rm-dt-only');
    expect(await page.locator('[data-x]').count()).toBe(0);
    const titles = await page.locator('#rm-dt-wide tbody td span[title]').evaluateAll((els) => els.map((el) => el.title));
    expect(titles).toContain(COUNTRY);
  });

  test('a missing country is a (missing) row that filters to its participant (#345)', async ({ page }) => {
    expect((await dist(page)).rows).toContain('(missing)');
    await clickDistRow(page, 'country', '(missing)');
    const s = await state(page);
    expect(s.tiles).toEqual(['F']);
    expect(s.chips).toEqual(['(missing)']);
  });
});

// rm_FixtureSplit(): S1 (US) has A, Amber; S2 has B (US), Green, and C (JP),
// Red. S2's weight is 3/5 windows, a calculated Red site flag.
test.describe('a site that spans countries', () => {
  let errors = [];
  test.beforeEach(async ({ page }) => {
    errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(SPLIT);
    await page.waitForFunction(() => document.querySelectorAll('#rm-tiles tbody tr').length > 0);
  });
  test.afterEach(() => expect(errors).toEqual([]));

  test('each participant counts toward their own country (#344)', async ({ page }) => {
    let d = await dist(page);
    expect(d.rows).toEqual(['JP', 'US']);
    expect(d.cells['US weight']).toMatchObject({ n: 2, amber: 1, red: 0 });
    expect(d.cells['JP weight']).toMatchObject({ n: 1, amber: 0, red: 1 });
    expect(d.counts).toMatchObject({ JP: [1, 1], US: [2, 2] });
    // By site flags, S2 counts once in the study and once in each country.
    await page.click('#rm-dist-sites');
    d = await dist(page);
    expect(d.cells['Study weight']).toMatchObject({ n: 1, red: 1 });
    expect(d.cells['JP weight']).toMatchObject({ n: 1, red: 1 });
    expect(d.cells['US weight']).toMatchObject({ n: 1, red: 1 });
  });

  test('the site is one row that lists its countries and filters by site alone (#344)', async ({ page }) => {
    await page.click('#rm-dist-site');
    const d = await dist(page);
    expect(d.rows).toEqual(['S2', 'S1']);
    expect(await page.locator('#rm-dist tr[data-rm-dist-key="S2"] td.rm-stick2').textContent()).toBe('JP, US');
    expect(d.cells['S2 weight']).toMatchObject({ n: 2, red: 1, dot: 'Red calculated' });
    await clickDistRow(page, 'site', 'S2');
    const s = await state(page);
    expect(s.tiles.sort()).toEqual(['B', 'C']);
    expect(s.chips).toEqual(['S2']);
    // A country filter keeps the site in either of its countries.
    await page.click('#rm-dist-country');
    await clickDistRow(page, 'country', 'JP');
    await page.click('#rm-dist-site');
    expect((await dist(page)).rows).toEqual(['S2']);
  });
});
