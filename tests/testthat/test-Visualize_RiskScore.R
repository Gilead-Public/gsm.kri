test_that("Visualize_RiskScore forwards an explicit SRS metric (#280)", {
  captured_metric <- NULL
  testthat::local_mocked_bindings(
    Widget_CrossStudyRiskScore = function(
        dfResults,
        dfMetrics,
        dfGroups,
        strGroupLevel,
        strRiskScoreMetric) {
      captured_metric <<- strRiskScoreMetric
      "widget"
    }
  )

  result <- Visualize_RiskScore(
    data.frame(MetricID = "Analysis_srs0002"),
    data.frame(MetricID = "Analysis_srs0002"),
    data.frame(GroupID = "1001"),
    strRiskScoreMetric = "Analysis_srs0002"
  )

  expect_equal(result, "widget")
  expect_equal(captured_metric, "Analysis_srs0002")
})
test_that("Visualize_RiskScore forwards comparison options (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    Widget_CrossStudyRiskScore = function(dfResults, dfMetrics, dfGroups,
                                          strGroupLevel, strRiskScoreMetric, ...) {
      captured <<- list(...)
      "widget"
    }
  )
  Visualize_RiskScore(
    data.frame(MetricID = "Analysis_srs0001"),
    data.frame(MetricID = "Analysis_srs0001"),
    data.frame(GroupID = "1001"),
    strComparisonRiskLabel = "Review Priority Score"
  )
  expect_equal(captured, list(strComparisonRiskLabel = "Review Priority Score"))
})
