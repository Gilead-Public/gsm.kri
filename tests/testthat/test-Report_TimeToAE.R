# Minimal but complete fixture: three sites so the Poisson fit is not saturated,
# one AE-free site so the report has something to flag.
make_ttae_report_fixture <- function() {
  lListings <- list(
    Mapped_SUBJ = tibble::tibble(
      studyid = "ST01",
      subjid = paste0("S", sprintf("%03d", 1:9)),
      invid = c(rep("INV-1", 3), rep("INV-2", 3), rep("INV-3", 3)),
      country = c(rep("USA", 3), rep("CAN", 3), rep("USA", 3)),
      firstparticipantdate = as.Date("2024-01-01"),
      timeonstudy = rep(100L, 9)
    ),
    Mapped_AE = tibble::tibble(
      subjid = c("S001", "S002", "S003", "S007"),
      aest_dt = as.Date(c(
        "2024-01-11",
        "2024-01-11",
        "2024-01-11",
        "2024-03-01"
      ))
    )
  )

  dfTransformed <- Input_TimeToEvent(
    lListings$Mapped_SUBJ,
    lListings$Mapped_AE
  ) %>%
    gsm.core::Transform_Rate()

  dfResults <- gsm.core::Analyze_Poisson(dfTransformed) %>%
    dplyr::mutate(
      Flag = c(-2, 0, 0)[rank(.data$Score)],
      MetricID = "Analysis_kri0019",
      StudyID = "ST01",
      SnapshotDate = as.Date("2024-05-01")
    ) %>%
    dplyr::select(-"PredictedCount")

  list(
    lListings = lListings,
    dfResults = dfResults,
    dfMetrics = tibble::tibble(
      MetricID = "Analysis_kri0019",
      Metric = "Time to First Adverse Event",
      Numerator = "Participants with an Adverse Event",
      Denominator = "Days at Risk to First Adverse Event",
      GroupLevel = "Site",
      AnalysisType = "poisson",
      Threshold = "-2,-1,2,3",
      AccrualThreshold = 10,
      Abbreviation = "TTAE"
    ),
    dfGroups = tibble::tibble(
      GroupID = c("INV-1", "INV-2", "INV-3"),
      Param = "invid",
      Value = c("INV-1", "INV-2", "INV-3"),
      GroupLevel = "Site"
    ),
    dfBounds = gsm.core::Analyze_Poisson_PredictBounds(
      dfTransformed,
      vThreshold = c(-2, -1, 2, 3)
    ) %>%
      dplyr::mutate(
        MetricID = "Analysis_kri0019",
        StudyID = "ST01",
        SnapshotDate = as.Date("2024-05-01")
      )
  )
}

test_that("Report_TimeToAE renders to a file", {
  testthat::skip_if_not_installed("plotly")
  fx <- make_ttae_report_fixture()

  out <- Report_TimeToAE(
    dfResults = fx$dfResults,
    dfMetrics = fx$dfMetrics,
    dfGroups = fx$dfGroups,
    dfBounds = fx$dfBounds,
    lListings = fx$lListings,
    strOutputDir = tempdir()
  )

  expect_true(file.exists(out))
})

test_that("Report_TimeToAE states the sign convention and the metric name", {
  testthat::skip_if_not_installed("plotly")
  fx <- make_ttae_report_fixture()

  out <- Report_TimeToAE(
    dfResults = fx$dfResults,
    dfMetrics = fx$dfMetrics,
    dfGroups = fx$dfGroups,
    dfBounds = fx$dfBounds,
    lListings = fx$lListings,
    strOutputDir = tempdir(),
    strOutputFile = "ttae-signs.html"
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_match(html, "Time to First Adverse Event")
  # the inverted-sign warning is the single most misreadable thing in this report
  expect_match(html, "negative")
  expect_match(html, "Kaplan-Meier")
  # the pseudo-front-matter block must render, not appear literally
  expect_no_match(html, "pagetitle:")
})

test_that("Report_TimeToAE requires results for the requested metric", {
  fx <- make_ttae_report_fixture()

  expect_error(
    Report_TimeToAE(
      dfResults = fx$dfResults,
      lListings = fx$lListings,
      strMetricID = "Analysis_kri9999"
    ),
    "not found in dfResults"
  )
})

test_that("Report_TimeToAE requires the listings it re-derives the cohort from", {
  fx <- make_ttae_report_fixture()

  expect_error(
    Report_TimeToAE(dfResults = fx$dfResults, lListings = NULL),
    "Mapped_SUBJ and Mapped_AE"
  )
  expect_error(
    Report_TimeToAE(
      dfResults = fx$dfResults,
      lListings = list(Mapped_SUBJ = fx$lListings$Mapped_SUBJ)
    ),
    "Mapped_SUBJ and Mapped_AE"
  )
})

test_that("Report_TimeToAE requires dfResults", {
  expect_error(Report_TimeToAE(), "dfResults must be provided")
})
