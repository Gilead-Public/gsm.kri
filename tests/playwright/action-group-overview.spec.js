const { test, expect } = require('@playwright/test');
const { fixtureUrl } = require('./fingerprint');

test('GroupOverview shows adjusted SRS beside existing Risk Score (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('GroupOverviewAction.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();

  const headers = await overview.locator('th').allInnerTexts();
  const riskIndex = headers.indexOf('Risk Score');
  expect(riskIndex).toBeGreaterThan(-1);
  expect(headers[riskIndex + 1]).toBe('Adjusted Risk Score');

  const firstRow = overview.locator('tbody tr').first();
  const baseline = Number(await firstRow.locator('td').nth(riskIndex).innerText());
  const adjusted = Number(await firstRow.locator('td').nth(riskIndex + 1).innerText());
  expect(Number.isFinite(baseline)).toBe(true);
  expect(Math.abs(adjusted - baseline / 2)).toBeLessThanOrEqual(0.5);
});

test('GroupOverview omits adjusted SRS when srs0002 is absent (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('GroupOverviewBaseline.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();
  await expect(overview.locator('th', { hasText: 'Adjusted Risk Score' })).toHaveCount(0);
});
