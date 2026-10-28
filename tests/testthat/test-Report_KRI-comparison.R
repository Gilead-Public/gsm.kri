test_that("Report_KRI forwards comparison score configuration (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  Report_KRI(
    lCharts = list(),
    dfResults = data.frame(),
    dfMetrics = data.frame(),
    dfGroups = data.frame(),
    strOutputFile = "report.html",
    strComparisonRiskMetric = "Analysis_custom_srs",
    strComparisonRiskLabel = "Comparison Score",
    strGroupSubset = "all"
  )

  expect_equal(
    captured$lParams$strComparisonRiskMetric,
    "Analysis_custom_srs"
  )
  expect_equal(
    captured$lParams$strComparisonRiskLabel,
    "Comparison Score"
  )
  expect_equal(captured$lParams$strGroupSubset, "all")
})

test_that("Report_KRI can disable and validates comparison scores (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  Report_KRI(
    strOutputFile = "report.html",
    strComparisonRiskMetric = NULL
  )
  expect_null(captured$lParams$strComparisonRiskMetric)

  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strComparisonRiskMetric = character()
    ),
    "strComparisonRiskMetric.*must be NULL"
  )
  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strComparisonRiskLabel = NA_character_
    ),
    "strComparisonRiskLabel.*must be a single"
  )
  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strGroupSubset = "unknown"
    ),
    "strGroupSubset.*must be NULL"
  )
})
test_that("Report_KRI forwards risk score detail (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  detail <- data.frame(GroupID = "1", MetricID = "Analysis_kri0001")
  Report_KRI(strOutputFile = "report.html", dfRiskScoreDetail = detail)
  expect_equal(captured$lParams$dfRiskScoreDetail, detail)

  Report_KRI(strOutputFile = "report.html")
  expect_null(captured$lParams$dfRiskScoreDetail)
})

test_that("Report_KRI renders without an action-weighted score (#280)", {
  skip_if_not(rmarkdown::pandoc_available())

  metric_ids <- c("Analysis_kri0001", "Analysis_kri0002", "Analysis_srs0001")
  results <- gsm.core::reportingResults %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  metrics <- gsm.core::reportingMetrics %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  bounds <- gsm.core::reportingBounds %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  # Site risk scores have no thresholds to chart.
  kri_ids <- setdiff(metric_ids, "Analysis_srs0001")
  charts <- MakeCharts(
    dfResults = results %>% dplyr::filter(.data$MetricID %in% kri_ids),
    dfGroups = gsm.core::reportingGroups,
    dfMetrics = metrics %>% dplyr::filter(.data$MetricID %in% kri_ids),
    dfBounds = bounds
  )
  detail <- data.frame(
    GroupID = unique(results$GroupID)[1],
    MetricID = "Analysis_kri0001",
    Weight = 4,
    EffectiveWeight = 0,
    ActionState = "No Action"
  )

  output_dir <- withr::local_tempdir()
  for (report_detail in list(NULL, detail)) {
    output_file <- Report_KRI(
      lCharts = charts,
      dfResults = results,
      dfMetrics = metrics,
      dfGroups = gsm.core::reportingGroups,
      strOutputDir = output_dir,
      strOutputFile = "no_srs0002.html",
      dfRiskScoreDetail = report_detail
    )
    html <- paste(readLines(file.path(output_dir, "no_srs0002.html"), warn = FALSE), collapse = "\n")
    expect_true(grepl("Widget_GroupOverview", html, fixed = TRUE))
    # Detail for a score that is not displayed never reaches the widget.
    expect_false(grepl("No Action", html, fixed = TRUE))
  }
})
