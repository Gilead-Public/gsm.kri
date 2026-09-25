const { test, expect } = require('@playwright/test');
const path = require('path');

const fileUrl = 'file://' + path.resolve(
  __dirname,
  'fixture',
  'CrossStudyActionSRS.html'
);

test('cross-study widget renders the configured srs0002 metric (#280)', async ({ page }) => {
  await page.goto(fileUrl);
  await page.waitForSelector('.site-summary', { timeout: 20000 });

  const averageBadges = await page
    .locator('.site-summary .gsm-srs[data-role="avg"]')
    .allTextContents();
  expect(averageBadges.length).toBeGreaterThan(0);
  expect(new Set(averageBadges)).toEqual(new Set(['5.0 Avg']));

  const detailScores = await page
    .locator('tr:not(.site-summary) .group-overview--siteRiskScore')
    .allTextContents();
  expect(detailScores.length).toBeGreaterThan(0);
  expect(detailScores.every((score) => score.includes('5'))).toBe(true);
});