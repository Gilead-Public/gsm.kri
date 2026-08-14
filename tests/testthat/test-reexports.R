test_that("relocated widget wrappers are re-exported from gsm.vizr (#291)", {
  relocated <- c(
    "Widget_BarChart",
    "Widget_BarChartOutput",
    "renderWidget_BarChart",
    "Widget_ScatterPlot",
    "Widget_ScatterPlotOutput",
    "renderWidget_ScatterPlot",
    "Widget_TimeSeries",
    "Widget_TimeSeriesOutput",
    "renderWidget_TimeSeries",
    "Widget_GroupOverview",
    "Widget_GroupOverviewOutput",
    "renderWidget_GroupOverview",
    "MakeChartConfig"
  )
  for (fn in relocated) {
    expect_identical(
      get(fn, envir = asNamespace("gsm.kri")),
      get(fn, envir = asNamespace("gsm.vizr")),
      info = fn
    )
  }
})
