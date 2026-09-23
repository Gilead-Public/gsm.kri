// Shared structural fingerprint of a rendered gsm.kri report page. Captures
// only DOM-observable facts (portable across machines / headless-chromium
// versions) so the same fingerprint can be captured on the 2.3.0 bundle,
// committed as baseline.json, and re-derived + diffed on 2.4.1.
// gsm.viz widgets render as Chart.js <canvas> (barChart/scatterPlot/timeSeries)
// or a d3 <table class="group-overview">; htmlwidgets wraps each in .html-widget.
const path = require('path');

const FIXTURES = {
  kri: 'Report_KRI.html',
  eligibility: 'Report_Eligibility.html',
};

function fixtureUrl(file) {
  return 'file://' + path.resolve(__dirname, 'fixture', file);
}

// Runs in the browser. canvasCount is unfiltered (stable regardless of whether a
// chart sits in a collapsed tab); the "visibly drew" assertion lives in the spec.
async function readFingerprint(page) {
  return await page.evaluate(() => ({
    htmlWidgetCount: document.querySelectorAll('.html-widget').length,
    canvasCount: document.querySelectorAll('.html-widget canvas').length,
    groupOverviewRowCounts: Array.from(
      document.querySelectorAll('table.group-overview')
    ).map((t) => t.querySelectorAll('tbody tr').length),
    selectCount: document.querySelectorAll('.html-widget select').length,
  }));
}

// The comparable subset (drops consoleErrors, which baseline.json stores for
// reference but the gate asserts == 0 separately).
function structural(o) {
  return {
    htmlWidgetCount: o.htmlWidgetCount,
    canvasCount: o.canvasCount,
    groupOverviewRowCounts: o.groupOverviewRowCounts,
    selectCount: o.selectCount,
  };
}

module.exports = { FIXTURES, fixtureUrl, readFingerprint, structural };
