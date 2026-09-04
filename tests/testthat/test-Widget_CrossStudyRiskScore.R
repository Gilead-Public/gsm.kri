testthat::test_that("Widget_CrossStudyRiskScore creates an htmlwidget (#71)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.75
  )

  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    Metric = "Risk Score",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  mock_summary <- data.frame(
    GroupID = "SiteA",
    RiskScore = 0.75
  )

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      mock_summary
    }
  )

  widget <- Widget_CrossStudyRiskScore(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    strGroupLevel = "Site"
  )

  expect_s3_class(widget, "htmlwidget")
  expect_match(widget$x$strWeightingSummary, "Site Risk Score Overview")
})

testthat::test_that("Widget_CrossStudyRiskScore errors if Analysis_srs0001 is missing (#71)", {
  dfResults <- data.frame(
    MetricID = "OtherMetric",
    Value = 1
  )

  dfMetrics <- data.frame(
    MetricID = "OtherMetric",
    Metric = "Other",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups
    ),
    "Analysis_srs0001"
  )
})

testthat::test_that("Widget_CrossStudyRiskScore accepts metadata without weights", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.75
  )
  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    MetricName = "Risk Score"
  )
  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      data.frame(GroupID = "SiteA", RiskScore = 0.75)
    }
  )

  widget <- Widget_CrossStudyRiskScore(dfResults, dfMetrics, dfGroups)

  expect_s3_class(widget, "htmlwidget")
  expect_identical(as.character(widget$x$strWeightingSummary), "null")
})

testthat::test_that("Widget_CrossStudyRiskScore supports an explicit SRS metric (#280)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0002",
    Value = 0.5
  )
  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0002",
    MetricName = "Action-weighted Risk Score"
  )
  dfGroups <- data.frame(GroupID = "SiteA", Site = "SiteA")
  captured_metric <- NULL

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      captured_metric <<- strRiskScoreMetric
      data.frame(GroupID = "SiteA", RiskScore = 0.5)
    }
  )
  widget <- Widget_CrossStudyRiskScore(
    dfResults,
    dfMetrics,
    dfGroups,
    strRiskScoreMetric = "Analysis_srs0002"
  )

  expect_equal(captured_metric, "Analysis_srs0002")
  expect_equal(
    jsonlite::fromJSON(widget$x$strSiteRiskMetric),
    "Analysis_srs0002"
  )
})

test_that("Cross-study widget JavaScript uses the configured SRS metric (#280)", {
  js <- readLines(system.file(
    "htmlwidgets",
    "lib",
    "renderCrossStudyRiskScoreTable.js",
    package = "gsm.kri"
  ))

  expect_true(any(grepl("input.strSiteRiskMetric", js, fixed = TRUE)))
  expect_false(any(grepl(
    "MetricID === 'Analysis_srs0001'",
    js,
    fixed = TRUE
  )))
})

testthat::test_that("Widget_CrossStudyRiskScore validates inputs (#71)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.5
  )

  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    Metric = "Risk Score",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = "not a data frame",
      dfMetrics = dfMetrics,
      dfGroups = dfGroups
    ),
    class = "simpleError"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = "not a data frame",
      dfGroups = dfGroups
    ),
    class = "simpleError"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = "not a data frame"
    ),
    class = "simpleError"
  )
})

test_that("Cross-study SRS report widget allows filtering on multiple studies (#171)", {
  skip_if_not_installed("qcthat")
  qcthat::ExpectUserAccepts(
    "Can filter cross-study SRS report on multiple studies.",
    intIssue = 171,
    chrInstructions = paste(
      "1. Navigate to the [Cross-Study SRS Report example](https://gilead-public.github.io/gsm.kri/dev/examples/Example_CrossStudySRS.html).",
      "2. Use the 'Filter by Study' option, following the instructions on the page.",
      sep = "\n"
    ),
    chrChecks = c(
      "The instructions for filtering by multiple studies make sense.",
      "The filters work as expected."
    )
  )
})
