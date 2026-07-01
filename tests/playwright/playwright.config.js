const { defineConfig } = require('@playwright/test');
// Assertions are DOM/data-structure based (no pixel snapshots), so there is
// nothing to commit as a baseline -- the suite is self-contained and portable
// across machines/headless-chromium versions. (This repo is also not a git
// repo, so committed PNG baselines were never an option.)
module.exports = defineConfig({
  testDir: '.',
  use: { headless: true },
});
