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
    strComparisonRiskLabel = "Comparison Score"
  )

  expect_equal(
    captured$lParams$strComparisonRiskMetric,
    "Analysis_custom_srs"
  )
  expect_equal(
    captured$lParams$strComparisonRiskLabel,
    "Comparison Score"
  )
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
})