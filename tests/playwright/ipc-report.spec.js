const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const FULL = 'file://' + path.resolve(__dirname, 'fixture', 'IPC.html');
const DEGRADED = 'file://' + path.resolve(__dirname, 'fixture', 'IPC_degraded.html');

// Facts of the fixture in tests/testthat/helper-ipc.R (render-ipc-fixture.R).
const STACK = [
  'Treatment complete per protocol',
  'Potential IP non-starter - within window',
  'Potential IP non-starter - outside window',
  'Confirmed IP non-starter',
  'Premature treatment discontinuation',
  'Potential premature treatment discontinuation',
  'Unrecognized status',
  'Treatment ongoing',
];
const DOSED_STATUSES = [
  'Treatment complete per protocol',
  'Premature treatment discontinuation',
  'Potential premature treatment discontinuation',
  'Treatment ongoing',
];
const N_ENROLLED = 29;
const N_DOSED = 17;
const N_DOSED_PLOTTED = 16; // P23 has no enrollment date, so no scatter point
const N_DOSED_JAPAN = 9;

// The same bubbling event gsm.vizr's bars() dispatches on a bar click, so the
// test does not depend on bar geometry that zoom can move.
function clickBar(page, chartId, row) {
  return page.evaluate(({ chartId, row }) => {
    document.getElementById(chartId).dispatchEvent(new CustomEvent('gsm-viz-select', {
      bubbles: true,
      detail: { type: 'click', chartId, category: row.GroupID, fill: 'Treatment ongoing', datum: row, metadata: { chartId, level: row.Level } },
    }));
  }, { chartId, row });
}
const country = (name) => ({ GroupID: name, OuterGroupID: null, Level: 'country' });
const site = (id, countryName) => ({ GroupID: id, OuterGroupID: countryName, Level: 'site' });

const datasetLabels = (page, id) => page.evaluate((id) =>
  document.getElementById(id).gsmChart.data.datasets.map((d) => d.label), id);
const categories = (page, id) => page.evaluate((id) =>
  document.getElementById(id).gsmChart.data.labels.slice(), id);
const selection = (page, id) => page.evaluate((id) => {
  const s = document.getElementById(id).gsmChart.data._selectionState_;
  return s && s.selection ? s.selection.values : [];
}, id);
const reasonCounts = (page, id) => page.evaluate((id) => {
  const out = {};
  document.getElementById(id).gsmChart.data.datasets[0].data.forEach((p) => { out[p._datum.reason] = p._datum.n; });
  return out;
}, id);
const scatterPoints = (page, id) => page.evaluate((id) => {
  const el = document.querySelector('#' + id + ' .js-plotly-plot');
  return el.data.filter((t) => Array.isArray(t.customdata) && t.visible === true)
    .reduce((n, t) => n + t.customdata.length, 0);
}, id);
const scatterVisibility = (page, id) => page.evaluate((id) => {
  const out = {};
  document.querySelector('#' + id + ' .js-plotly-plot').data.forEach((t) => { if (t.name) out[t.name] = t.visible; });
  return out;
}, id);
const listingRows = (page) => page.evaluate(() =>
  jQuery('#ipc-listing table.dataTable').DataTable().rows({ search: 'applied' }).count());

async function showTab(page, section, tab) {
  await page.locator('#' + section + ' .nav-pills a', { hasText: tab }).click();
}

// Plotly's legend toggle is an SVG rect over the entry; click its screen position.
async function legendClick(page, id, name, dbl) {
  await showTab(page, id.split('-')[1], 'Time to event');
  const text = page.locator('#' + id + ' .legendtext', { hasText: new RegExp('^' + name + '$') });
  await text.scrollIntoViewIfNeeded();
  const box = await text.boundingBox();
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  if (dbl) await page.mouse.dblclick(x, y);
  else await page.mouse.click(x, y);
  await page.waitForTimeout(600);
}

test.describe('full report', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(FULL);
    await page.waitForFunction(() => {
      const ok = (id) => document.getElementById(id) && document.getElementById(id).gsmChart;
      return ['ipc-study-status', 'ipc-country-status', 'ipc-site-status', 'ipc-study-reasons', 'ipc-country-reasons', 'ipc-site-reasons'].every(ok) &&
        document.querySelectorAll('.js-plotly-plot').length === 3 && window.jQuery &&
        document.querySelector('#ipc-listing table.dataTable');
    }, null, { timeout: 30000 });
  });

  test('renders six bar charts and three scatters (#320)', async ({ page }) => {
    for (const level of ['study', 'country', 'site']) {
      for (const kind of ['status', 'reasons']) {
        expect(await page.locator('#ipc-' + level + '-' + kind + ' canvas').count()).toBe(1);
      }
      expect(await page.locator('#ipc-' + level + '-tte .js-plotly-plot').count()).toBe(1);
    }
  });

  test('status datasets follow the stack order (#320, #332)', async ({ page }) => {
    for (const level of ['study', 'country', 'site']) {
      expect(await datasetLabels(page, 'ipc-' + level + '-status')).toEqual(STACK);
    }
  });

  test('country and site charts zoom; the study chart does not (#320)', async ({ page }) => {
    const wheel = (id) => page.evaluate((id) => {
      const z = document.getElementById(id).gsmChart.options.plugins.zoom;
      return !!(z && z.zoom && z.zoom.wheel && z.zoom.wheel.enabled);
    }, id);
    expect(await wheel('ipc-study-status')).toBe(false);
    expect(await wheel('ipc-country-status')).toBe(true);
    expect(await wheel('ipc-site-status')).toBe(true);
  });

  test('Dosed narrows statuses, scatters and listing, not reasons (#320, #332)', async ({ page }) => {
    const reasonsBefore = await reasonCounts(page, 'ipc-study-reasons');
    await page.click('#ipc-dosed-Y');
    expect(await page.getAttribute('#ipc-dosed-Y', 'aria-pressed')).toBe('true');
    // P29's outcome is unrecognised, so Unrecognized status stays under Dosed.
    expect(await datasetLabels(page, 'ipc-study-status')).toEqual(
      ['Treatment complete per protocol', 'Premature treatment discontinuation',
        'Potential premature treatment discontinuation', 'Unrecognized status', 'Treatment ongoing']);
    expect(await reasonCounts(page, 'ipc-study-reasons')).toEqual(reasonsBefore);
    expect(await scatterPoints(page, 'ipc-study-tte')).toBe(N_DOSED_PLOTTED);
    expect(await listingRows(page)).toBe(N_DOSED);
  });

  test('Not dosed zeroes every reason and shows the notes (#320)', async ({ page }) => {
    await page.click('#ipc-dosed-N');
    for (const level of ['study', 'country', 'site']) {
      const counts = await reasonCounts(page, 'ipc-' + level + '-reasons');
      expect(Object.values(counts).every((n) => n === 0)).toBe(true);
      expect(await page.evaluate((id) => document.getElementById(id).style.display,
        'ipc-' + level + '-reasons-note')).toBe('');
    }
  });

  test('a country click narrows the Country and Site tabs and the listing (#320)', async ({ page }) => {
    const studyReasons = await reasonCounts(page, 'ipc-study-reasons');
    await page.click('#ipc-dosed-Y');
    // "Unknown" holds one not-dosed participant, so it has no bar under Dosed.
    const countries = await categories(page, 'ipc-country-status');
    expect(countries).toEqual(['Canada', 'Japan', 'Poland']);
    await clickBar(page, 'ipc-country-status', country('Japan'));
    expect(await page.textContent('#ipc-chip-country .ipc-chip-value')).toBe('Japan');
    expect(await categories(page, 'ipc-country-status')).toEqual(countries);
    expect(await selection(page, 'ipc-country-status')).toEqual(['Japan']);
    expect(await categories(page, 'ipc-site-status')).toEqual(['JP01', 'JP02']);
    for (const id of ['ipc-country-reasons', 'ipc-site-reasons']) {
      expect(await reasonCounts(page, id)).toEqual(
        { 'Adverse Event': 1, 'Not yet recorded': 1, 'Physician Decision': 0, 'Withdrawal by Subject': 0 });
    }
    expect(await reasonCounts(page, 'ipc-study-reasons')).toEqual(studyReasons);
    expect(await scatterPoints(page, 'ipc-study-tte')).toBe(N_DOSED_PLOTTED);
    expect(await scatterPoints(page, 'ipc-country-tte')).toBe(N_DOSED_JAPAN - 1);
    expect(await listingRows(page)).toBe(N_DOSED_JAPAN);
  });

  test('a site click narrows the Site tab and listing; re-click and chips clear (#320, #332)', async ({ page }) => {
    await clickBar(page, 'ipc-country-status', country('Japan'));
    await clickBar(page, 'ipc-site-status', site('JP02', 'Japan'));
    expect(await page.textContent('#ipc-chip-site .ipc-chip-value')).toBe('JP02');
    expect(await selection(page, 'ipc-site-status')).toEqual(['JP02']);
    expect(await reasonCounts(page, 'ipc-site-reasons')).toEqual(
      { 'Adverse Event': 0, 'Not yet recorded': 1, 'Physician Decision': 0, 'Withdrawal by Subject': 0 });
    expect(await reasonCounts(page, 'ipc-country-reasons')).toEqual(
      { 'Adverse Event': 1, 'Not yet recorded': 1, 'Physician Decision': 0, 'Withdrawal by Subject': 0 });
    expect(await scatterPoints(page, 'ipc-site-tte')).toBe(6);
    expect(await listingRows(page)).toBe(6);

    await clickBar(page, 'ipc-site-status', site('JP02', 'Japan'));
    expect(await page.isVisible('#ipc-chip-site')).toBe(false);
    expect(await page.textContent('#ipc-chip-country .ipc-chip-value')).toBe('Japan');
    expect(await listingRows(page)).toBe(15);

    await clickBar(page, 'ipc-site-status', site('JP02', 'Japan'));
    await page.click('#ipc-chip-country button');
    expect(await page.isVisible('#ipc-chip-country')).toBe(false);
    expect(await page.isVisible('#ipc-chip-site')).toBe(false);
    expect(await listingRows(page)).toBe(N_ENROLLED);
  });

  test('a site ID with regex characters filters the listing exactly (#320)', async ({ page }) => {
    await clickBar(page, 'ipc-site-status', site('PL-01 (B)', 'Poland'));
    expect(await listingRows(page)).toBe(5);
  });

  test('fill mode survives a filter and count mode shows counts (#320, #332)', async ({ page }) => {
    const ongoingJP01 = () => page.evaluate(() => {
      const c = document.getElementById('ipc-site-status').gsmChart;
      const ds = c.data.datasets.find((d) => d.label === 'Treatment ongoing');
      return ds.data.find((p) => p.x === 'JP01').y;
    });
    await clickBar(page, 'ipc-country-status', country('Japan'));
    expect(await categories(page, 'ipc-site-status')).toEqual(['JP01', 'JP02']);
    expect(await page.evaluate(() =>
      document.getElementById('ipc-site-status').gsmChart.data._spec_.stat)).toBe('percent');
    expect(await ongoingJP01()).toBeCloseTo(400 / 9, 1);
    await page.evaluate(() => {
      const c = document.getElementById('ipc-site-status').gsmChart;
      c.helpers.updateSpec(c, { position: 'stack', stat: 'count' });
    });
    expect(await ongoingJP01()).toBe(4);
  });

  test('segment labels lead with the value the axis shows (#320)', async ({ page }) => {
    const label = (valueType) => page.evaluate((valueType) =>
      document.getElementById('ipc-country-status').gsmChart.data._spec_.annotations.labels.segment
        .formatter(0, null, { valueType, value: 41, percent: 62.3 }), valueType);
    expect(await label('percent')).toBe('62.3% (41)');
    expect(await label('raw')).toBe('41 (62.3%)');
  });

  test('legend clicks hide and isolate a status in every scatter, across filters (#320, #332)', async ({ page }) => {
    const ids = ['ipc-study-tte', 'ipc-country-tte', 'ipc-site-tte'];
    await legendClick(page, 'ipc-study-tte', 'Treatment ongoing', false);
    for (const id of ids) expect((await scatterVisibility(page, id))['Treatment ongoing']).toBe('legendonly');
    await legendClick(page, 'ipc-study-tte', 'Treatment ongoing', false);
    await legendClick(page, 'ipc-study-tte', 'Treatment ongoing', true);
    for (const id of ids) {
      const v = await scatterVisibility(page, id);
      expect(v['Treatment ongoing']).toBe(true);
      expect(v['Treatment complete per protocol']).toBe('legendonly');
    }
    await page.click('#ipc-dosed-Y');
    const v = await scatterVisibility(page, 'ipc-site-tte');
    expect(v['Treatment ongoing']).toBe(true);
    expect(v['Treatment complete per protocol']).toBe('legendonly');
  });

  test('every scatter legend lists the four dosed statuses in stack order (#332)', async ({ page }) => {
    for (const id of ['ipc-study-tte', 'ipc-country-tte', 'ipc-site-tte']) {
      const names = await page.evaluate((id) => document.querySelector('#' + id + ' .js-plotly-plot').data
        .filter((t) => t.name).sort((a, b) => a.legendrank - b.legendrank).map((t) => t.name), id);
      expect(names, id).toEqual(STACK);
      for (const status of DOSED_STATUSES) expect(names, id).toContain(status);
    }
  });

  test('the listing shows Study complete as Y, N or blank next to Consent withdrawn (#332)', async ({ page }) => {
    const r = await page.evaluate(() => {
      const dt = jQuery('#ipc-listing table.dataTable').DataTable();
      const headers = dt.columns().header().toArray().map((h) => h.textContent);
      const col = headers.indexOf('Study complete');
      const value = (id) => dt.rows().data().toArray().find((row) => row[0] === id)[col];
      return { col, next: headers[col + 1], values: ['P02', 'P19', 'P01'].map(value) };
    });
    expect(r.col).toBeGreaterThan(-1);
    expect(r.next).toBe('Consent withdrawn');
    expect(r.values).toEqual(['Y', 'N', '']);
  });

  test('the listing shows Study Drug Completed per Protocol instead of the PTD flag (#332)', async ({ page }) => {
    const r = await page.evaluate(() => {
      const dt = jQuery('#ipc-listing table.dataTable').DataTable();
      const headers = dt.columns().header().toArray().map((h) => h.textContent);
      const col = headers.indexOf('Study Drug Completed per Protocol');
      const value = (id) => dt.rows().data().toArray().find((row) => row[0] === id)[col];
      return { headers, values: ['P06', 'P09', 'P02', 'P01', 'P19'].map(value) };
    });
    expect(r.headers).toContain('Study Drug Completed per Protocol');
    expect(r.headers).not.toContain('Premature treatment discontinuation');
    expect(r.values).toEqual(['N', 'Potential No', 'Y', '', '']);
  });

  test('search narrows the listing; the CSV holds every participant (#320, #332)', async ({ page }) => {
    await page.click('#ipc-dosed-Y');
    expect(await listingRows(page)).toBe(N_DOSED);
    await page.fill('#ipc-listing input[type="search"]', 'Canada');
    expect(await listingRows(page)).toBeLessThan(N_DOSED);
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.click('#ipc-listing .buttons-csv'),
    ]);
    const csv = fs.readFileSync(await download.path(), 'utf8').trim().split('\n');
    expect(csv.length).toBe(N_ENROLLED + 1);
    expect(csv[0]).toContain('Participant ID');
    expect(csv[0]).not.toContain('dosed');
    expect(csv[0]).toContain('Study Drug Completed per Protocol');
    expect(csv[0]).toContain('Study complete');
    expect(csv[0]).toContain('Drug discontinuation reason');
    expect(csv[0]).not.toContain('Days since enrollment');
  });
  test('every reason chart labels each non-zero bar with % and count (#320)', async ({ page }) => {
    for (const level of ['study', 'country', 'site']) {
      await showTab(page, level, 'Reasons');
      const id = 'ipc-' + level + '-reasons';
      await page.waitForTimeout(300);
      const r = await page.evaluate((id) => {
        const ch = document.getElementById(id).gsmChart;
        // Thin bars, as with a study's full reason list, are where labels went missing.
        ch.resize(ch.width, 180);
        ch.update('none');
        const drawn = ch.$datalabels._labels.filter((l) => l._model).map((l) => l._model.lines.join(' '));
        const nonZero = ch.data.datasets[0].data.filter((p) => p._datum.n > 0).length;
        return { drawn, nonZero };
      }, id);
      expect(r.nonZero, id).toBeGreaterThan(0);
      expect(r.drawn.length, id).toBe(r.nonZero);
      for (const t of r.drawn) expect(t).toMatch(/^\d+\.\d% \(\d+\)$/);
    }
  });

  test('a reason bar reaching the axis end keeps its label on the canvas (#320)', async ({ page }) => {
    for (const level of ['study', 'country', 'site']) {
      await showTab(page, level, 'Reasons');
      const id = 'ipc-' + level + '-reasons';
      await page.waitForTimeout(300);
      const r = await page.evaluate((id) => {
        const ch = document.getElementById(id).gsmChart;
        // Worst case: the longest bar ends exactly at the axis maximum.
        ch.options.scales.x.max = Math.max(...ch.data.datasets[0].data.map((p) => p.x));
        ch.update('none');
        const ctx = ch.ctx;
        return ch.$datalabels._labels.filter((l) => l._model).map((l) => {
          ctx.save();
          ctx.font = l._model.font.string;
          const w = ctx.measureText(l._model.lines.join(' ')).width;
          ctx.restore();
          return { right: l._el.x + 4 + w, width: ch.width };
        });
      }, id);
      expect(r.length, id).toBeGreaterThan(0);
      for (const l of r) expect(l.right, id).toBeLessThanOrEqual(l.width);
    }
  });

  test('a jump to the listing leaves its controls clear of the filter strip (#320)', async ({ page }) => {
    await page.evaluate(() => document.getElementById('participant-listing').scrollIntoView());
    await page.waitForTimeout(300);
    const r = await page.evaluate(() => ({
      strip: document.getElementById('ipc-filter-strip').getBoundingClientRect().bottom,
      button: document.querySelector('#participant-listing .dt-buttons').getBoundingClientRect().top,
    }));
    expect(r.button).toBeGreaterThanOrEqual(r.strip);
  });

  test('the overview and listing scroll inside their column instead of widening the page (#320)', async ({ page }) => {
    await page.setViewportSize({ width: 900, height: 800 });
    await page.waitForTimeout(300);
    const r = await page.evaluate(() => {
      const x = (id) => getComputedStyle(document.getElementById(id)).overflowX;
      return { overflowX: [x('study-overview'), x('ipc-listing')].join(), pageWider: document.documentElement.scrollWidth > document.documentElement.clientWidth };
    });
    expect(r.overflowX).toBe('auto,auto');
    expect(r.pageWider).toBe(false);
  });
});

test('degraded page shows the not-available text and dosed participants as Unrecognized (#320, #332)', async ({ page }) => {
  await page.goto(DEGRADED);
  await page.waitForFunction(() => document.getElementById('ipc-study-status') &&
    document.getElementById('ipc-study-status').gsmChart, null, { timeout: 30000 });
  expect(await page.locator('text=Treatment completion data not available').count()).toBeGreaterThan(0);
  expect(await page.locator('#ipc-study-reasons').count()).toBe(0);
  for (const level of ['study', 'country', 'site']) {
    const labels = await datasetLabels(page, 'ipc-' + level + '-status');
    for (const status of DOSED_STATUSES) expect(labels).not.toContain(status);
    expect(labels).toContain('Unrecognized status');
    expect(labels).toContain('Confirmed IP non-starter');
  }
});
