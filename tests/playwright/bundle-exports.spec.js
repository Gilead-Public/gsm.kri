const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const LIB_DIR = path.resolve(__dirname, '..', '..', 'inst', 'htmlwidgets', 'lib');

function currentBundleDir() {
  const dirs = fs.readdirSync(LIB_DIR).filter((d) => d.startsWith('gsm.viz-'));
  if (dirs.length !== 1) {
    throw new Error(
      'Expected exactly one gsm.viz-* bundle under ' + LIB_DIR + ', found: ' + dirs.join(', ')
    );
  }
  return path.join(LIB_DIR, dirs[0]);
}

// The bundle is ~1 MB and every source-marker check below wants the same bytes.
// Read it lazily and once: lazily so a missing/duplicated bundle still surfaces
// as a test failure rather than a collection-time crash, once so adding the next
// marker check costs nothing.
let bundleSrc;
function bundleSource() {
  if (bundleSrc === undefined) {
    bundleSrc = fs.readFileSync(path.join(currentBundleDir(), 'index.js'), 'utf8');
  }
  return bundleSrc;
}

// esbuild builds the bundle with --global-name=gsmViz, so loading index.js sets
// window.gsmViz, and the default export (window.gsmViz.default) is the entrypoint
// object the widgets call as gsmViz.default.barChart(...) etc.
test('vendored bundle exposes bars + facetBars alongside the existing entrypoints', async ({ page }) => {
  await page.goto('about:blank');
  await page.addScriptTag({ path: path.join(currentBundleDir(), 'index.js') });
  const keys = await page.evaluate(() =>
    Object.keys((window.gsmViz && window.gsmViz.default) || {})
  );
  expect(keys).toEqual(expect.arrayContaining([
    'barChart', 'bars', 'facetBars', 'groupOverview', 'scatterPlot', 'sparkline', 'timeSeries',
  ]));
});

// zoomPlugin is registered via Chart.register(...) inside the bundle (it is NOT a
// key on the gsmViz export object). The 2.4.0 bundle contains the plugin source;
// 2.3.0 does not. A source marker is the reliable, framework-agnostic check.
test('vendored bundle registers the chartjs zoom plugin', () => {
  expect(bundleSource()).toContain('chartjs-plugin-zoom');
});

// The category-axis overlap heuristic (gsm.viz #550) is what replaces the
// hand-rolled label-fit formatter in Widget_PrematureDeathBucketBar.js. Like the
// zoom plugin above it is not a key on the export object, so a source marker is
// the reliable check that the vendored bundle actually carries it.
test('vendored bundle carries the category-axis overlap heuristic', () => {
  expect(bundleSource()).toContain('avoidCategoryOverlap');
});
