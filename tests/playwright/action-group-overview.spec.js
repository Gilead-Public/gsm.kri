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

test('pkgdown site report displays the weighted disposition draft (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('Example_SiteReport.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();

  const headers = await overview.locator('th').allInnerTexts();
  const riskIndex = headers.indexOf('Risk Score');
  expect(riskIndex).toBeGreaterThan(-1);
  expect(headers[riskIndex + 1]).toBe('Adjusted Risk Score (Draft)');
  await expect(overview.getByRole('spinbutton', { name: 'Action window (days)' })).toHaveCount(0);
  await expect(overview.getByRole('checkbox')).toHaveCount(1);
  await expect(overview.getByRole('checkbox', { name: 'Highlight actions within 90 days' })).toBeChecked();
  expect(await overview.locator('td.group-overview--recent-action').count()).toBeGreaterThan(0);

  const rows = overview.locator('tbody tr');
  expect(await rows.count()).toBeGreaterThan(0);
  const differs = await rows.evaluateAll((items, index) =>
    items.some((row) => row.cells[index].innerText !== row.cells[index + 1].innerText),
    riskIndex
  );
  expect(differs).toBe(true);
});

test('clicking an adjusted score lists the KRIs behind it (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('Example_SiteReport.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();

  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));

  // The adjusted score is its own measure: no difference marker beside it.
  const scoreCells = overview.locator('td.group-overview--comparisonRiskScore');
  expect(await scoreCells.count()).toBeGreaterThan(0);
  const scoreTexts = await scoreCells.allInnerTexts();
  expect(scoreTexts.every((text) => /^\d+$/.test(text.trim()))).toBe(true);

  const detail = overview.locator('tr.group-overview--comparison-detail');
  await expect(detail).toHaveCount(0);

  // Pick a site with a recent covered decision so the breakdown explains it.
  const clickScore = (id) => scoreCells.evaluateAll(
    (cells, groupID) => cells.find((td) => td.__data__.GroupID === groupID).click(),
    id
  );
  const groupIDs = await scoreCells.evaluateAll((cells) => cells.map((td) => td.__data__.GroupID));
  let groupID = null;
  for (const id of groupIDs) {
    await clickScore(id);
    if ((await detail.innerText()).includes('Recently addressed')) {
      groupID = id;
      break;
    }
    await clickScore(id);
  }
  expect(groupID).not.toBeNull();
  await expect(detail).toContainText(groupID);
  await expect(detail).toContainText('Counted');
  await expect(detail).not.toContainText('Points');

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
  await clickScore(groupID);
  await expect(detail).toHaveCount(0);
});

test('site overview has no adjusted score detail when srs0002 is absent (#280)', async ({ page }) => {
  await page.goto(fixtureUrl('GroupOverviewBaseline.html'));

  const overview = page.locator('.Widget_GroupOverview');
  await expect(overview).toBeVisible();
  await expect(overview.locator('td.group-overview--comparisonRiskScore')).toHaveCount(0);
  await expect(overview.locator('.group-overview--comparison-detail')).toHaveCount(0);
});
