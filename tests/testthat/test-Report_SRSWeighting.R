test_that("Report_SRSWeighting explains and displays metric contributions", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Metric = c("Adverse Event Rate", "Query Rate"),
    Flag = c("-2,-1,0,1,2", "0,1,2"),
    RiskScoreWeight = c("32,16,0,1,2", "0,1,2")
  )

  html <- Report_SRSWeighting(dfMetrics) %>% as.character()

  expect_match(html, "How metric weighting contributes")
  expect_match(html, "divided by the total possible points")
  expect_match(html, "Adverse Event Rate")
  expect_match(html, "Query Rate")
  expect_match(html, "32 points")
  expect_match(html, "94\\.1%")
  expect_match(html, "5\\.9%")
  expect_match(html, "Low red \\(-2\\)")
  expect_match(html, "Not configured")
})

test_that("Report_SRSWeighting excludes inactive metrics", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_active", "Analysis_inactive"),
    Metric = c("Active metric", "Inactive metric"),
    Flag = c("0,1,2", "0,1,2"),
    RiskScoreWeight = c("0,1,2", "0,4,8"),
    Active = c(TRUE, FALSE)
  )

  html <- Report_SRSWeighting(dfMetrics) %>% as.character()

  expect_match(html, "Active metric")
  expect_no_match(html, "Inactive metric")
  expect_match(html, "100\\.0%")
})

test_that("Report_SRSWeighting includes only metrics used in SRS results", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_included", "Analysis_excluded"),
    Metric = c("Included metric", "Excluded metric"),
    Flag = c("0,1,2", "0,1,2"),
    RiskScoreWeight = c("0,1,2", "0,4,8")
  )
  dfResults <- data.frame(MetricID = "Analysis_included")

  html <- Report_SRSWeighting(dfMetrics, dfResults) %>% as.character()

  expect_match(html, "Included metric")
  expect_no_match(html, "Excluded metric")
  expect_match(html, "Total possible points: 2")
  expect_match(html, "100\\.0%")
})

test_that("Report_SRSWeighting validates metric metadata", {
  expect_error(
    Report_SRSWeighting(data.frame(MetricID = "Analysis_kri0001")),
    "Missing required columns"
  )
  expect_error(
    Report_SRSWeighting(
      data.frame(
        MetricID = "Analysis_kri0001",
        Flag = "0,1,2",
        RiskScoreWeight = "0,1,2"
      ),
      data.frame(Other = "value")
    ),
    "dfResults must be a data frame"
  )
})
