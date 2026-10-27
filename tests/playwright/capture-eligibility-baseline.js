// Captures a renderer-agnostic structural fingerprint of the Eligibility
// report's 8 bar-chart tabs (+ the already-canvas time series widget), across
// the plotly -> gsm.qtl's gsm.vizr::bars() migration (#286). Charts are keyed
// by their Rmd section id / tab label -- stable anchors independent of the
// plotly-vs-canvas rendering mechanism -- not by the auto-generated
// htmlwidget-<hash> id, which is a rendering-library detail. Per-chart facts
// (categories, series names/colours, orientation, stacking, tab order) are
// DOM/data facts a canvas swap must reproduce; no plotly trace internals or
// pixel data are recorded. Each chart carries a `renderer` field ("plotly" or
// "bars") identifying which reading branch produced it -- informational only
// (never asserted on), so a plotly-vs-bars capture pair can still be diffed
// on every other field.
//   node tests/playwright/capture-eligibility-baseline.js            # writes eligibility-baseline.json
//   OUT=after node tests/playwright/capture-eligibility-baseline.js  # prints a fresh capture for diffing
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'Report_Eligibility.html');

// [sectionId, tabLabel] in the tabset's actual left-to-right order (the two
// "Criteria/X" vs "X/Criteria" section ids intentionally do not sort the same
// as their tab labels -- pandoc slugs the id from the label's word order).
const BAR_TABS = [
  ['site', 'Site'],
  ['site-by', 'Site (by %)'],
  ['country', 'Country'],
  ['source', 'Source'],
  ['criteriasite-edc-ie-data-only', 'Criteria/Site (EDC I/E data only)'],
  ['criteriacountry-edc-ie-data-only', 'Criteria/Country (EDC I/E data only)'],
  ['sitecriteria-edc-ie-data-only', 'Site/Criteria (EDC I/E data only)'],
  ['countrycriteria-edc-ie-data-only', 'Country/Criteria (EDC I/E data only)'],
];

// Reads each tab's widget in-browser. gsm.vizr::bars() canvas widgets expose
// their Chart.js instance at el.gsmChart (same technique as
// capture-pd-baseline.js's readBucketChart/readReasonChart); the plotly
// branch is kept only so this same script still reads a pre-#286 capture.
// None of the eligibility bars() calls pass a metadata$chartId, so el.id
// stays the auto-generated htmlwidget-<hash> id -- select the widget by its
// position inside the Rmd's own section pane instead.
function readBarTabs(page) {
  return page.evaluate((tabs) => {
    return tabs.map(([id, label]) => {
      const pane = document.getElementById(id);
      const barsEl = pane ? pane.querySelector('.bars.html-widget') : null;
      const plotlyEl = pane ? pane.querySelector('.plotly') : null;

      if (barsEl && barsEl.gsmChart) {
        const c = barsEl.gsmChart;
        const opts = c.config.options;
        return {
          sectionId: id,
          tabLabel: label,
          found: true,
          renderer: 'bars',
          title: (opts.plugins && opts.plugins.title && opts.plugins.title.text) || null,
          orientation: opts.indexAxis === 'y' ? 'horizontal' : 'vertical',
          categories: c.data.labels.slice(),
          series: c.data.datasets.map((d) => ({ name: d.label, color: d.backgroundColor || null })),
          stacked: !!((opts.scales.x && opts.scales.x.stacked) || (opts.scales.y && opts.scales.y.stacked)),
        };
      }

      if (plotlyEl) {
        const layout = plotlyEl.layout || {};
        const xa = layout.xaxis || {};
        const ya = layout.yaxis || {};
        // The categorical axis is whichever carries a non-numeric
        // categoryarray; orientation is derived from WHICH axis that is, not
        // plotly's own "orientation" trace field (its 'v'/'h' vocabulary is a
        // plotly-ism that does not describe the visual bar direction
        // consistently across libs).
        const isCategorical = (ax) => Array.isArray(ax.categoryarray) &&
          ax.categoryarray.some((v) => Number.isNaN(Number(v)));
        const yCat = isCategorical(ya);
        const xCat = isCategorical(xa);
        const categories = yCat ? ya.categoryarray.slice() : (xCat ? xa.categoryarray.slice() : []);
        const series = (plotlyEl.data || [])
          // Named non-bar traces exist too (the count-label text traces carry
          // the series name); only bar traces are series in the bars() sense.
          .filter((t) => t.name && t.type === 'bar')
          .map((t) => ({ name: t.name, color: (t.marker && t.marker.color) || null }));
        return {
          sectionId: id,
          tabLabel: label,
          found: true,
          renderer: 'plotly',
          title: (layout.title && layout.title.text) || null,
          orientation: yCat ? 'horizontal' : (xCat ? 'vertical' : null),
          categories,
          series,
          stacked: layout.barmode === 'relative' || layout.barmode === 'stack',
        };
      }

      return { sectionId: id, tabLabel: label, found: false };
    });
  }, BAR_TABS);
}

function readTabOrder(page) {
  return page.evaluate(() => {
    const nav = document.querySelector('#bar-charts ul.nav-pills, .section.level2 ul.nav-pills');
    return Array.from(nav.querySelectorAll('li')).map((li) => ({
      label: li.textContent.trim(),
      default: li.classList.contains('active'),
    }));
  });
}

function readTimeSeriesWidget(page) {
  return page.evaluate(() => {
    const el = document.querySelector('.Widget_TimeSeries');
    return el ? { present: true, isCanvas: !!el.querySelector('canvas') } : { present: false };
  });
}

// Footnotes/captions attached to the report (gt table source notes, if any).
// The bundled fixture's Study Overview table carries none today; recorded as
// an explicit empty array so a later report that adds one shows up as a diff.
function readFootnotes(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.gt_footnote, .gt_sourcenote'))
      .map((e) => e.textContent.trim())
      .filter(Boolean)
  );
}

(async () => {
  const label = process.env.OUT || 'baseline';
  const artifacts = path.resolve(__dirname, 'artifacts');
  fs.mkdirSync(artifacts, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(fileUrl);
  await page.waitForTimeout(1500);

  const tabOrder = await readTabOrder(page);
  const charts = await readBarTabs(page);
  const timeSeriesChart = await readTimeSeriesWidget(page);
  const footnotes = await readFootnotes(page);

  // Screenshot evidence for hover + legend only (no pixel diffing, just
  // reviewer-facing artifacts). The default "Site" tab is active on load, so
  // no tab click is needed first. Chart.js draws its legend on the same
  // <canvas> as the bars, so one hover screenshot of the widget covers both;
  // plotly's SVG legend is a separate element, hence the two-shot branch.
  const barsCanvas = page.locator('#site .bars.html-widget canvas');
  if (await barsCanvas.count() > 0) {
    await barsCanvas.first().hover();
    await page.waitForTimeout(300);
    await page.locator('#site .bars.html-widget').first()
      .screenshot({ path: path.join(artifacts, `eligibility-hover.${label}.png`) }).catch(() => {});
    await page.locator('#site .bars.html-widget').first()
      .screenshot({ path: path.join(artifacts, `eligibility-legend.${label}.png`) }).catch(() => {});
  } else {
    // Plotly's hover layer only fires on the bar's own SVG path, not the
    // container div -- hovering the container leaves the tooltip unrendered.
    const chart = page.locator('#site .js-plotly-plot');
    await page.locator('#site .bars .point path').first().hover({ force: true });
    await page.waitForTimeout(300);
    await chart.screenshot({ path: path.join(artifacts, `eligibility-hover.${label}.png`) }).catch(() => {});
    await page.locator('#site .legend').first().screenshot({ path: path.join(artifacts, `eligibility-legend.${label}.png`) }).catch(() => {});
  }

  const out = {
    tabOrder,
    charts,
    timeSeriesChart,
    footnotes,
    consoleErrors: errors.length,
  };

  await browser.close();

  if (label === 'baseline') {
    fs.writeFileSync(path.join(__dirname, 'eligibility-baseline.json'), JSON.stringify(out, null, 2) + '\n');
    console.log('Wrote eligibility-baseline.json:\n' + JSON.stringify(out, null, 2));
  } else {
    console.log(`Captured ${label}:\n` + JSON.stringify(out, null, 2));
  }
})();
