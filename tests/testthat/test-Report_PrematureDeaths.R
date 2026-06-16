dfResults <- tibble::tibble(
  GroupID = c("S1", "S2", "S3"),
  GroupLevel = "Patient",
  MetricID = "Analysis_pat0015",
  Numerator = c(1, 1, 0),
  Denominator = 1,
  Metric = c(1, 1, 0),
  Score = c(1, 1, 0),
  Flag = c(2, 2, 0),
  SnapshotDate = as.Date("2026-05-01")
)

dfMetrics <- tibble::tibble(
  MetricID = "Analysis_pat0015",
  Metric = "Premature Death (Patient)"
)

dfGroups <- tibble::tibble(
  GroupID = c("S1", "S2", "S3"),
  Param = "subjid",
  Value = c("S1", "S2", "S3"),
  GroupLevel = "Patient"
)

lListings <- list(
  Mapped_SUBJ = tibble::tibble(
    studyid = "ST01",
    subjid = c("S1", "S2", "S3"),
    invid = c("INV-1", "INV-1", "INV-2"),
    country = c("USA", "USA", "CAN"),
    rgmn_dt = as.Date(c("2026-01-26", "2026-01-10", "2026-04-15"))
  ),
  Mapped_Death = tibble::tibble(
    subjid = c("S1", "S2"),
    death_dt = as.Date(c("2026-02-15", "2026-03-01")),
    death_dy = c(20, 50),
    death_reason = c("Cardiac arrest", "Sepsis"),
    deathcls = c("Adverse Event", "Disease Progression"),
    aerel = c("Yes", "No")
  ),
  Mapped_STUDCOMP = tibble::tibble(
    studyid = "ST01",
    subjid = "S3",
    compyn = "N",
    compreas = "Withdrawal by Subject",
    mincreated_dts = as.Date("2026-05-30")
  )
)

test_that("Report_PrematureDeaths renders to a file {#223}", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- Report_PrematureDeaths(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    nWindowDays = 90,
    strOutputDir = tempdir()
  )
  expect_true(file.exists(out))
})

test_that("Report_PrematureDeaths validates nWindowDays {#223}", {
  expect_error(
    Report_PrematureDeaths(lListings = lListings, nWindowDays = -1),
    "nWindowDays must be a positive number"
  )
})

test_that("Report_PrematureDeaths warns when nWindowDays disagrees with dfResults {#223}", {
  # Test the window-consistency guard directly (warnings don't propagate
  # through rmarkdown::render boundaries; the helper is exported for this purpose).
  expect_warning(
    pd_CheckWindowConsistency(nWindowDays = 10, nPremature = 0, nFlagged = 2),
    "disagrees with the window used to produce dfResults"
  )
})

test_that("Report_PrematureDeaths renders the studcomp discontinuation note {#246}", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- Report_PrematureDeaths(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    nWindowDays = 90,
    strOutputDir = tempdir()
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Study discontinuation", html)) # CAT-3 note text
  expect_true(grepl("studcomp", html, ignore.case = TRUE))
})

test_that("Report bucket-bar toggle updates labels and autoranges both modes {#246}", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- Report_PrematureDeaths(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    nWindowDays = 90,
    strOutputDir = tempdir()
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # applyMode rebuilds the on-bar text per mode (count vs %) and pushes it with y.
  expect_match(html, "var texts =", fixed = TRUE)
  expect_match(html, "text: texts", fixed = TRUE)
  # % mode autoranges the y-axis (no pinned [0, 100]) so a legend deselect
  # rescales the bars, consistent with count mode.
  expect_match(
    html,
    '"yaxis.ticksuffix": "%", "yaxis.autorange": true',
    fixed = TRUE
  )
})

test_that("Report_PrematureDeaths includes country filter JS and banner {#246}", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- Report_PrematureDeaths(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    nWindowDays = 90,
    strOutputDir = tempdir()
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Filter banner present
  expect_true(grepl("pd-filter-banner", html))

  # JS controller present
  expect_true(grepl("pdResetFilter", html))
  expect_true(grepl("plotly_click", html))

  # Country-site map JSON present
  expect_true(grepl("countrySiteMap", html))

  # Premature-death site count + honest banner count (sites-with-death / enrolled)
  expect_true(grepl("countryPrematureCount", html))
  expect_true(grepl("sites with at least 1 premature death", html))

  # Chart container IDs present
  expect_true(grepl('id="pd-country-buckets"', html))
  expect_true(grepl('id="pd-site-buckets"', html))
  expect_true(grepl('id="pd-site-scatter"', html))
})

test_that("Report_PrematureDeaths wires the site-barchart listing filter {#221}", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- Report_PrematureDeaths(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    nWindowDays = 90,
    strOutputDir = tempdir()
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Site click is wired as a second, independent filter source.
  expect_match(html, "attachSiteClick", fixed = TRUE)
  expect_match(html, "function applySiteFilter", fixed = TRUE)
  expect_match(html, "highlightSiteBar", fixed = TRUE)
  # Both filters route through one listing owner.
  expect_match(html, "function applyListingFilter", fixed = TRUE)
  # Two-line banner: the new site row + its reset.
  expect_match(html, "pd-filter-site-row", fixed = TRUE)
  expect_match(html, "pd-site-filter-text", fixed = TRUE)
  expect_match(html, "window.pdResetSiteFilter", fixed = TRUE)
})
