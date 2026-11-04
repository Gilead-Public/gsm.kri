test_that("Widget_FlagOverTime creates a valid HTML widget", {
  widget <- Widget_FlagOverTime(
    gsm.core::reportingResults,
    gsm.core::reportingMetrics,
    strGroupLevel = "Site"
  )
  expect_s3_class(widget, c("WidgetGroupOverview", "htmlwidget"))
  expect_true(
    stringr::str_detect(
      widget$x$gtFlagOverTime,
      "<table class=\"gt_table\""
    )
  )
})

test_that("Widget_FlagOverTime assertions works", {
  reportingResults_modified <- as.list(gsm.core::reportingResults)
  reportingMetrics_modified <- as.list(gsm.core::reportingMetrics)
  expect_error(
    Widget_FlagOverTime(
      reportingResults_modified,
      gsm.core::reportingMetrics,
      strGroupLevel = "Site"
    ),
    "dfResults is not a data.frame"
  )
  expect_error(
    Widget_FlagOverTime(
      gsm.core::reportingResults,
      reportingMetrics_modified,
      strGroupLevel = "Site"
    ),
    "dfMetrics is not a data.frame"
  )
  expect_error(
    Widget_FlagOverTime(
      gsm.core::reportingResults,
      gsm.core::reportingMetrics,
      strGroupLevel = 1
    ),
    "strGroupLevel is not a character"
  )
})
