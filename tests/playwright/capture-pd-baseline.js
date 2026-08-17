// Captures a renderer-agnostic structural fingerprint of the PD report's bucket
// + reason charts and their drilldown/filter behaviour, ahead of the
// gsm.viz-wrapper -> gsm.vizr::bars() migration (#288). The fingerprint records
// only DOM-observable facts that must survive BOTH a canvas-widget swap and an
// event-name rename (pdBucketClick -> gsm-viz-select): chart ids, categories,
// stack order, colours, caption text, tabset structure, and the *effect* of a
// country-bucket click (narrowed site/reason categories, filter chip state) --
// never the mechanism (event name, widget internals) used to reach that state.
//   node tests/playwright/capture-pd-baseline.js            # writes pd-baseline.json
//   OUT=after node tests/playwright/capture-pd-baseline.js  # prints a fresh capture for diffing
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report.html');

const BUCKET_IDS = { study: 'pd-study-buckets', country: 'pd-country-buckets', site: 'pd-site-buckets' };
const REASON_IDS = { study: 'pd-study-reasons', country: 'pd-country-reasons' };
// The scatter charts are explicitly out of scope for this migration (#120 stays
// open); recorded only so a later diff can confirm they were left untouched.
const SCATTER_IDS = ['pd-study-scatter', 'pd-country-scatter', 'pd-site-scatter'];

function readBucketChart(page, id) {
  return page.evaluate((id) => {
    const c = document.querySelector('#' + id).gsmChart;
    const s = c.config.options.plugins.subtitle;
    const colors = {};
    c.data.datasets.forEach((d) => { colors[d.label] = d.backgroundColor; });
    return {
      chartId: id,
      categories: c.data.labels.slice(),
      stackOrder: c.data.datasets.map((d) => d.label),
      colors,
      captionShown: !!s.display,
      captionText: s.text.slice(),
    };
  }, id);
}

function readReasonChart(page, id) {
  return page.evaluate((id) => {
    const c = document.querySelector('#' + id).gsmChart;
    return {
      chartId: id,
      categories: c.data.labels.slice(),
      color: c.data.datasets[0].backgroundColor,
    };
  }, id);
}

async function readTabsets(page) {
  return page.evaluate(() => {
    const groups = Array.from(document.querySelectorAll('div.section.level2'))
      .filter((s) => s.querySelector(':scope > ul.nav-pills'));
    return groups.map((g) => {
      const h2 = g.querySelector(':scope > h2');
      const nav = g.querySelector(':scope > ul.nav-pills');
      const tabs = Array.from(nav.querySelectorAll('a')).map((a) => ({
        label: a.textContent.trim(),
        default: a.parentElement.classList.contains('active'),
      }));
      return { group: h2 ? h2.textContent.trim() : null, tabs };
    });
  });
}

function readChipState(page) {
  return page.evaluate(() => ({
    bannerShown: getComputedStyle(document.getElementById('pd-filter-banner')).display !== 'none',
    countryChipShown: getComputedStyle(document.getElementById('pd-filter-country-chip')).display !== 'none',
    countryChipValue: document.getElementById('pd-filter-country-value').textContent,
    siteChipShown: getComputedStyle(document.getElementById('pd-filter-site-chip')).display !== 'none',
  }));
}

function readDrilldownCategories(page) {
  return page.evaluate(() => ({
    siteCategories: document.querySelector('#pd-site-buckets').gsmChart.data.labels.slice(),
    reasonCategories: document.querySelector('#pd-country-reasons').gsmChart.data.labels.slice(),
  }));
}

// The report's current mechanism for a country-bucket selection is the
// pdBucketClick CustomEvent; only used here to DRIVE the browser into the
// filtered state, never stored as part of the captured fingerprint below.
function clickCountryBucket(page, country) {
  return page.evaluate((country) => document.querySelector('#pd-country-buckets')
    .dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true,
      detail: { level: 'country', groupId: country, country } })), country);
}

(async () => {
  const label = process.env.OUT || 'baseline';
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(fileUrl);
  await page.waitForSelector('#pd-site-buckets canvas', { timeout: 20000 });

  const bucketCharts = {};
  for (const [level, id] of Object.entries(BUCKET_IDS)) bucketCharts[level] = await readBucketChart(page, id);

  const reasonCharts = {};
  for (const [level, id] of Object.entries(REASON_IDS)) reasonCharts[level] = await readReasonChart(page, id);

  const tabsets = await readTabsets(page);
  const defaultChips = await readChipState(page);
  const before = await readDrilldownCategories(page);

  await clickCountryBucket(page, 'USA');
  await page.waitForTimeout(300);
  const afterFilterChips = await readChipState(page);
  const afterFilter = await readDrilldownCategories(page);

  await page.evaluate(() => document.getElementById('pd-filter-reset').click());
  await page.waitForTimeout(300);
  const afterResetChips = await readChipState(page);
  const afterReset = await readDrilldownCategories(page);

  const out = {
    bucketCharts,
    reasonCharts,
    scatterChartIds: SCATTER_IDS,
    tabsets,
    drilldown: {
      trigger: 'selecting a country bucket narrows the site chart to that country\'s sites and swaps the country reason chart to that country\'s reason slice',
      defaultChips,
      before,
      afterCountryFilter: Object.assign({ country: 'USA' }, afterFilter, {
        bannerShown: afterFilterChips.bannerShown,
        countryChipShown: afterFilterChips.countryChipShown,
        countryChipValue: afterFilterChips.countryChipValue,
      }),
      afterReset: Object.assign({}, afterReset, {
        bannerShown: afterResetChips.bannerShown,
        countryChipShown: afterResetChips.countryChipShown,
      }),
    },
    consoleErrors: errors.length,
  };

  await browser.close();

  if (label === 'baseline') {
    fs.writeFileSync(path.join(__dirname, 'pd-baseline.json'), JSON.stringify(out, null, 2) + '\n');
    console.log('Wrote pd-baseline.json:\n' + JSON.stringify(out, null, 2));
  } else {
    console.log(`Captured ${label}:\n` + JSON.stringify(out, null, 2));
  }
})();
