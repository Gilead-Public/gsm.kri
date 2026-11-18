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
    .locator('tbody tr:not(.site-summary) td.group-overview--siteRiskScore')
    .allTextContents();
  expect(detailScores.length).toBeGreaterThan(0);
  expect(detailScores.every((score) => score.includes('5'))).toBe(true);
});
test('cross-study rows show the adjusted score and recent-action highlights (#280)', async ({ page }) => {
  const fixture = path.resolve(__dirname, 'fixture', 'CrossStudyActionHighlight');
  const [closed, open, expired] = require('fs')
    .readFileSync(`${fixture}.csv`, 'utf8').trim().split(/\r?\n/).slice(1)
    .map((line) => line.split(',').map((value) => value.replace(/^"|"$/g, '')));
  await page.goto('file://' + `${fixture}.html`);
  await page.waitForSelector('.site-summary', { timeout: 20000 });

  const headers = await page.locator('#unified-thead th').allTextContents();
  const riskScore = headers.indexOf('Risk Score');
  expect(riskScore).toBeGreaterThan(-1);
  expect(headers[riskScore + 1]).toBe('Adjusted Risk Score');
  const adjusted = await page.locator('td.group-overview--comparisonRiskScore').allTextContents();
  expect(adjusted.length).toBeGreaterThan(0);
  expect(new Set(adjusted)).toEqual(new Set(['42']));

  const legend = page.getByRole('list', { name: 'Highlighted KRI legend' });
  expect(await legend.getByRole('listitem').allTextContents())
    .toEqual(['Closed action', 'Open action', 'Other action state']);

  const cellStyle = (row) => page.locator('td.group-overview--metric').evaluateAll((cells, [study, site, metric]) => {
    const cell = cells.find((candidate) => candidate.__data__.GroupID === `${study} ${site}` &&
      candidate.__data__.MetricID === metric);
    return cell && {
      highlighted: cell.classList.contains('group-overview--recent-action'),
      fill: getComputedStyle(cell).backgroundColor,
      border: getComputedStyle(cell).boxShadow,
      action: cell.title.split('\n').at(-1)
    };
  }, row);
  expect(await cellStyle(closed)).toMatchObject({ highlighted: true, fill: 'rgb(232, 245, 233)',
    border: 'rgb(45, 164, 78) 0px 0px 0px 3px inset' });
  expect(await cellStyle(open)).toMatchObject({ highlighted: true, fill: 'rgb(255, 235, 238)',
    border: 'rgb(207, 34, 46) 0px 0px 0px 3px inset' });
  expect(await cellStyle(expired)).toMatchObject({ highlighted: false,
    action: expect.stringMatching(/^Latest action: No Action\. .*Days ago: 120\.$/) });
  await expect(page.locator('td.group-overview--recent-action')).toHaveCount(2);

  await page.getByRole('checkbox', { name: 'Highlight actions within 90 days' }).uncheck();
  await expect(page.locator('td.group-overview--recent-action')).toHaveCount(0);
  await expect(page.locator('td.group-overview--comparisonRiskScore').first()).toHaveText('42');
});
