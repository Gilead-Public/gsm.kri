test_that("MakeCharts makes charts", {
  # Mock Visualize_Metric() since that has its own tests.
  local_mocked_bindings(
    Visualize_Metric = function(
      dfResults,
      dfBounds,
      dfGroups,
      dfMetrics,
      strMetricID,
      ...
    ) {
      list(
        dfResults = nrow(dfResults),
        dfBounds = nrow(dfBounds),
        dfGroups = nrow(dfGroups),
        dfMetrics = nrow(dfMetrics),
        strMetricID = strMetricID,
        bDebug = FALSE
      )
    }
  )
  charts <- MakeCharts(
    dfResults = gsm.core::reportingResults,
    dfBounds = gsm.core::reportingBounds,
    dfGroups = gsm.core::reportingGroups,
    dfMetrics = gsm.core::reportingMetrics
  )
  expect_snapshot({
    str(charts, max.level = 2)
  })
})
