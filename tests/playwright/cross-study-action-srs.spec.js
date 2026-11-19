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
    .toEqual(['Closed Action', 'Open Action', 'No Action']);

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

test('cross-study XLSX downloads export the visible summary and long detail (#280)', async ({ page }) => {
  const fixture = path.resolve(__dirname, 'fixture', 'CrossStudyActionHighlight');
  await page.goto('file://' + `${fixture}.html`);
  await page.waitForSelector('.site-summary', { timeout: 20000 });
  await expect(page.getByRole('button', { name: /CSV/ })).toHaveCount(0);
  // Workbook parts are stored uncompressed, so the sheet XML is read as text.
  const readXlsx = (bytes) => {
    const text = bytes.toString('utf8');
    const sheet = text.slice(text.indexOf('<sheetData>'), text.indexOf('</sheetData>'));
    const unescape = (value) => value.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&amp;/g, '&');
    return [...sheet.matchAll(/<row r="\d+">(.*?)<\/row>/g)].map(([, cells]) => {
      const row = [];
      for (const [, column, body] of cells.matchAll(/<c r="([A-Z]+)\d+"[^>]*>(.*?)<\/c>/g)) {
        const index = [...column].reduce((n, letter) => n * 26 + letter.charCodeAt(0) - 64, 0) - 1;
        row[index] = unescape((body.match(/<v>(.*?)<\/v>/) || body.match(/<t[^>]*>(.*?)<\/t>/))[1]);
      }
      return Array.from(row, (value) => value ?? '');
    });
  };
  const download = async (name) => {
    const pending = page.waitForEvent('download');
    await page.getByRole('button', { name }).click();
    const file = await pending;
    const bytes = require('fs').readFileSync(await file.path());
    expect(bytes.subarray(0, 2).toString()).toBe('PK');
    return { name: file.suggestedFilename(), rows: readXlsx(bytes) };
  };
  const visibleSites = () => page.locator('tbody[id^="site-tbody-"]').evaluateAll((bodies) => bodies
    .filter((body) => body.style.display !== 'none')
    .map((body) => body.querySelector('.site-summary').dataset));

  const summary = await download('Download site summary (XLSX)');
  expect(summary.name).toBe('cross-study-site-summary.xlsx');
  expect(summary.rows[0]).toEqual(['Site', 'Studies', 'Enrolled', 'Avg SRS', 'Max SRS']);
  const sites = await visibleSites();
  expect(summary.rows.slice(1).map((row) => row[0]))
    .toEqual(sites.map((site) => `${site.siteId} (${site.investigatorName})`));
  expect(summary.rows.slice(1).map((row) => row[3]))
    .toEqual(sites.map((site) => String(Number(Number(site.avgRiskScore).toFixed(1)))));

  const detail = await download('Download site/study detail (XLSX)');
  expect(detail.name).toBe('cross-study-site-study-detail.xlsx');
  expect(detail.rows[0]).toEqual(['Site', 'Investigator', 'Study', 'Snapshot Date', 'Enrolled', 'Red Flags',
    'Amber Flags', 'Risk Score', 'Adjusted Risk Score', 'KRI', 'KRI Name', 'Metric ID', 'Flag', 'Score',
    'Numerator', 'Denominator', 'Metric', 'Action State', 'Last Addressed', 'Days Ago', 'Action Within 90 Days']);
  const columns = Object.fromEntries(detail.rows[0].map((name, index) => [name, index]));
  const body = detail.rows.slice(1);
  expect(new Set(body.map((row) => row[columns.Site]))).toEqual(new Set(sites.map((site) => site.siteId)));
  expect(body.every((row) => row[columns['Adjusted Risk Score']] === '42')).toBe(true);
  const highlighted = await page.locator('td.group-overview--recent-action').count();
  expect(body.filter((row) => row[columns['Action Within 90 Days']] === 'Yes')).toHaveLength(highlighted);

  await page.locator('#site-search').fill(sites[0].siteId);
  const filtered = await download('Download site summary (XLSX)');
  expect(filtered.rows.slice(1).map((row) => row[0])).toEqual([`${sites[0].siteId} (${sites[0].investigatorName})`]);
});
