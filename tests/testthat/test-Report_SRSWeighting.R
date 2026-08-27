test_that("Report_SRSWeighting explains and displays metric contributions", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Metric = c("Adverse Event Rate", "Query Rate"),
    Flag = c("-2,-1,0,1,2", "0,1,2"),
    RiskScoreWeight = c("32,16,0,1,2", "0,1,2")
  )

  html <- Report_SRSWeighting(dfMetrics) %>% as.character()

  expect_match(html, "Site Risk Score Overview")
  expect_match(html, "divided by the total possible points")
  expect_match(html, "Each metric's maximum contribution is the highest")
  expect_no_match(html, "Total possible points:")
  expect_match(html, "Adverse Event Rate")
  expect_match(html, "Query Rate")
  expect_match(html, "32 points")
  expect_match(html, "94\\.1%")
  expect_match(html, "5\\.9%")
  expect_match(html, "Low red \\(-2\\)")
  expect_match(html, "Not configured")
  expect_match(html, "Example SRS")
  expect_match(html, "Selected flag")
  expect_match(html, "Metric score")
  expect_match(html, "srs-weighting-flag-select")
  expect_match(html, 'data-weight="32"')
  expect_match(html, 'value="0" data-weight="0" selected=""')
  expect_match(html, "0\\.0")
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
  expect_match(html, 'data-total-possible="2"')
  expect_match(html, "100\\.0%")
})

test_that("Report_SRSWeighting initializes metrics without neutral flags", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_positive",
    Metric = "Positive flags only",
    Flag = "1,2",
    RiskScoreWeight = "1,2"
  )

  html <- Report_SRSWeighting(dfMetrics) %>% as.character()

  expect_match(html, 'value="1" data-weight="1" selected=""')
  expect_match(html, "srs-weighting-total-score[^>]*>50\\.0")
  expect_match(html, "srs-weighting-selected-points[^>]*>1")
})

test_that("Report_SRSWeighting serializes calculator values independently of locale", {
  withr::local_options(OutDec = ",")
  dfMetrics <- data.frame(
    MetricID = "Analysis_decimal",
    Metric = "Decimal weight",
    Flag = "0,1",
    RiskScoreWeight = "0,1.5"
  )

  html <- Report_SRSWeighting(dfMetrics) %>% as.character()

  expect_match(html, 'data-total-possible="1.5"')
  expect_match(html, 'data-weight="1.5"')
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
