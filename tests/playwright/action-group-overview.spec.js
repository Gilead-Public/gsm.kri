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

test('pkgdown site report calculates and displays exported ActionLog score (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('Example_SiteReport.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();

  const headers = await overview.locator('th').allInnerTexts();
  const riskIndex = headers.indexOf('Risk Score');
  expect(riskIndex).toBeGreaterThan(-1);
  expect(headers[riskIndex + 1]).toBe('Adjusted Risk Score');

  const rows = overview.locator('tbody tr');
  expect(await rows.count()).toBeGreaterThan(0);
  const differs = await rows.evaluateAll((items, index) =>
    items.some((row) => row.cells[index].innerText !== row.cells[index + 1].innerText),
    riskIndex
  );
  expect(differs).toBe(true);
});

test('adjusted score badge and click-through list the KRIs behind it (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('Example_SiteReport.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();

  const badges = overview.locator('.group-overview--comparison-delta');
  expect(await badges.count()).toBeGreaterThan(0);
  const badgeCell = overview.locator(
    'td.group-overview--comparisonRiskScore:has(.group-overview--comparison-delta)'
  );

  const detail = overview.locator('.group-overview--comparison-detail');
  await expect(detail.locator('table')).toHaveCount(0);

  await badgeCell.first().click();
  const rows = detail.locator('tbody tr');
  expect(await rows.count()).toBeGreaterThan(0);
  await expect(detail).toContainText('No Action');

  // A second click on the same score closes the breakdown.
  await badgeCell.first().click();
  await expect(detail.locator('table')).toHaveCount(0);
});

test('site overview has no adjusted score detail when srs0002 is absent (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('GroupOverviewBaseline.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();
  await expect(overview.locator('.group-overview--comparison-delta')).toHaveCount(0);
  await expect(overview.locator('.group-overview--comparison-detail')).toHaveCount(0);
});
