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

  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));

  const detail = overview.locator('tr.group-overview--comparison-detail');
  await expect(detail).toHaveCount(0);

  const clicked = badgeCell.first();
  const groupID = await clicked.evaluate((td) => td.__data__.GroupID);
  await clicked.click();
  await expect(detail).toHaveCount(1);
  await expect(detail).toContainText('No Action');
  await expect(detail).toContainText(groupID);

  // The breakdown sits directly under the clicked group's row.
  const followsGroup = await detail.evaluate((row, id) => {
    const above = row.previousElementSibling.querySelector('td.group-overview--comparisonRiskScore');
    return above !== null && above.__data__.GroupID === id;
  }, groupID);
  expect(followsGroup).toBe(true);

  // Redrawing the table (a subset change) keeps the breakdown under its group.
  await overview.locator('select').first().selectOption({ index: 0 });
  await expect(detail).toHaveCount(1);
  await expect(detail).toContainText(groupID);
  expect(errors).toEqual([]);

  // A second click on the same score closes the breakdown.
  await overview.locator('td.group-overview--comparisonRiskScore')
    .filter({ has: page.locator('.group-overview--comparison-delta') })
    .evaluateAll((cells, id) => cells.find((td) => td.__data__.GroupID === id).click(), groupID);
  await expect(detail).toHaveCount(0);
});

test('site overview has no adjusted score detail when srs0002 is absent (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('GroupOverviewBaseline.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();
  await expect(overview.locator('.group-overview--comparison-delta')).toHaveCount(0);
  await expect(overview.locator('.group-overview--comparison-detail')).toHaveCount(0);
});
