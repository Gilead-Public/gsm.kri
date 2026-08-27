const { test, expect } = require('@playwright/test');
const path = require('path');

const fileUrl = 'file://' + path.resolve(__dirname, 'fixture', 'CrossStudySRS.html');

// Fixture is seeded (tests/playwright/render-fixture-crossstudy.R, seed=123), so
// these site/study IDs and scores are deterministic. SITE0004 is in all three
// studies with distinct SRS/enrollment per study, which is what exercises the
// "Filter by Study" recalculation path.
const MULTI_STUDY_SITE = 'SITE0004';
const FILTER_STUDY = 'STUDY003';
// Overall enrollment across all sites, descending (baseline TotalEnrollment).
const ENROLLMENT_DESC_ORDER = ['SITE0003', 'SITE0004', 'SITE0002', 'SITE0001', 'SITE0005', 'SITE0006'];

test.beforeEach(async ({ page }) => {
  await page.goto(fileUrl);
  // The table is built entirely client-side by renderCrossStudyRiskScoreTable;
  // wait for the first summary row rather than a fixed timeout.
  await page.waitForSelector('.site-summary', { timeout: 20000 });
});

test('Weighting tab explains metric contributions to SRS', async ({ page }) => {
  const weightingTab = page.getByRole('tab', { name: 'How SRS Weighting Works' });
  const weightingPanel = page.getByRole('tabpanel', { name: 'How SRS Weighting Works' });

  await expect(weightingPanel).toBeHidden();
  await weightingTab.click();

  await expect(weightingTab).toHaveAttribute('aria-selected', 'true');
  await expect(weightingPanel).toBeVisible();
  await expect(weightingPanel).toContainText('Adverse Event Rate');
  await expect(weightingPanel).toContainText('Maximum contribution');
  await expect(weightingPanel).toContainText('Share of total possible SRS');
});

test('Sort by dropdown includes Enrollment Count options and reorders sites', async ({ page }) => {
  await page.selectOption('#sort-by', 'enrollment-desc');
  const order = await page.evaluate(() => {
    const table = document.querySelector('.cross-study-unified-table');
    return Array.from(table.querySelectorAll('tbody[id^="site-tbody-"]')).map((tbody) => {
      return tbody.querySelector('.site-summary').dataset.siteId;
    });
  });
  expect(order).toEqual(ENROLLMENT_DESC_ORDER);
});

test('selecting one study for a multi-study site recalculates its Avg/Max SRS and Enrollment badges', async ({ page }) => {
  const before = await page.evaluate((siteId) => {
    const tbody = Array.from(document.querySelectorAll('tbody[id^="site-tbody-"]'))
      .find((tb) => tb.querySelector('.site-summary').dataset.siteId === siteId);
    const sr = tbody.querySelector('.site-summary');
    return {
      avg: sr.querySelector('.gsm-srs[data-role="avg"]').textContent,
      enrollment: sr.querySelector('.gsm-enrollmentCount').textContent,
    };
  }, MULTI_STUDY_SITE);
  // Baseline (no filter) shows the all-studies aggregate, not a single study's value.
  expect(before.avg).toBe('31.0 Avg');
  expect(before.enrollment).toBe('228 Enrolled');

  await page.evaluate((study) => {
    const select = document.querySelector('#study-filter');
    Array.from(select.options).forEach((opt) => { opt.selected = opt.value === study; });
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }, FILTER_STUDY);

  const after = await page.evaluate((siteId) => {
    const tbody = Array.from(document.querySelectorAll('tbody[id^="site-tbody-"]'))
      .find((tb) => tb.querySelector('.site-summary').dataset.siteId === siteId);
    const sr = tbody.querySelector('.site-summary');
    const avgBadge = sr.querySelector('.gsm-srs[data-role="avg"]');
    const enrollmentBadge = sr.querySelector('.gsm-enrollmentCount');
    return {
      avgText: avgBadge.textContent,
      avgTitle: avgBadge.title,
      enrollmentText: enrollmentBadge.textContent,
      enrollmentTitle: enrollmentBadge.title,
    };
  }, MULTI_STUDY_SITE);

  // STUDY003's own SRS/enrollment for this site, not the 3-study aggregate.
  expect(after.avgText).toBe('33.2 Avg');
  expect(after.avgTitle).toBe('33.2 for 1 selected study. 31.0 for all 3 studies.');
  expect(after.enrollmentText).toBe('79 Enrolled');
  expect(after.enrollmentTitle).toBe('79 for 1 selected study. 228 for all 3 studies.');
});

test('the detail row for the SELECTED study is the one highlighted and moved to the top (#regression: was reading a different study)', async ({ page }) => {
  // Detail rows are expanded by default (no click needed) -- clicking the
  // summary row here would actually COLLAPSE them.
  await page.evaluate((study) => {
    const select = document.querySelector('#study-filter');
    Array.from(select.options).forEach((opt) => { opt.selected = opt.value === study; });
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }, FILTER_STUDY);

  const result = await page.evaluate((siteId) => {
    const tbody = Array.from(document.querySelectorAll('tbody[id^="site-tbody-"]'))
      .find((tb) => tb.querySelector('.site-summary').dataset.siteId === siteId);
    const detailRows = Array.from(tbody.querySelectorAll('tr:not(.site-summary)'));
    const firstRow = detailRows[0];
    const groupLabelCell = firstRow.querySelector('.group-overview--GroupLabel');
    return {
      firstRowStudyId: firstRow.dataset.studyId,
      firstRowIsHighlighted: firstRow.classList.contains('study-row-selected'),
      // Ground truth: the row's OWN rendered label, independent of our tagging logic.
      firstRowLabelText: groupLabelCell.textContent,
    };
  }, MULTI_STUDY_SITE);

  expect(result.firstRowStudyId).toBe(FILTER_STUDY);
  expect(result.firstRowIsHighlighted).toBe(true);
  // The row's own displayed content must actually be for the selected study --
  // this is what catches a stale/incorrect studyId tag.
  expect(result.firstRowLabelText).toContain(FILTER_STUDY);
});

test('the row highlight survives a hover (#regression: gsmViz mouseout was clearing it)', async ({ page }) => {
  // Detail rows are expanded by default (no click needed) -- clicking the
  // summary row here would actually COLLAPSE them.
  await page.evaluate((study) => {
    const select = document.querySelector('#study-filter');
    Array.from(select.options).forEach((opt) => { opt.selected = opt.value === study; });
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }, FILTER_STUDY);

  const highlightedLocator = page.locator(
    `tbody:has(tr.site-summary[data-site-id="${MULTI_STUDY_SITE}"]) tr.study-row-selected`
  );
  await expect(highlightedLocator).toHaveCount(1);

  // gsmViz's addRowHighlighting.js sets inline background-color on mouseover
  // and clears it (sets to null) on mouseout -- reproduce that exact sequence.
  await highlightedLocator.scrollIntoViewIfNeeded();
  await highlightedLocator.hover();
  await page.mouse.move(0, 0); // move away to fire mouseout

  await expect(highlightedLocator).toHaveClass(/study-row-selected/);
  const bg = await highlightedLocator.evaluate((el) => getComputedStyle(el).backgroundColor);
  expect(bg).toBe('rgb(255, 243, 205)'); // #fff3cd, from the !important stylesheet rule
});

test('Reset Filters reverts badges to the all-studies baseline', async ({ page }) => {
  await page.evaluate((study) => {
    const select = document.querySelector('#study-filter');
    Array.from(select.options).forEach((opt) => { opt.selected = opt.value === study; });
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }, FILTER_STUDY);

  await page.click('#reset-filters');

  const after = await page.evaluate((siteId) => {
    const tbody = Array.from(document.querySelectorAll('tbody[id^="site-tbody-"]'))
      .find((tb) => tb.querySelector('.site-summary').dataset.siteId === siteId);
    const sr = tbody.querySelector('.site-summary');
    return {
      avg: sr.querySelector('.gsm-srs[data-role="avg"]').textContent,
      enrollment: sr.querySelector('.gsm-enrollmentCount').textContent,
      highlightedRows: tbody.querySelectorAll('tr.study-row-selected').length,
    };
  }, MULTI_STUDY_SITE);

  expect(after.avg).toBe('31.0 Avg');
  expect(after.enrollment).toBe('228 Enrolled');
  expect(after.highlightedRows).toBe(0);
});
