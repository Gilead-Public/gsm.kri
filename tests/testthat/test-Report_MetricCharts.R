dummy_chart <- htmltools::tags$div("dummy chart content")

test_that("Handles all supported chart types (#53)", {
  lCharts <- list(
    scatterPlot = dummy_chart,
    barChart = dummy_chart,
    timeSeries = dummy_chart
  ) %>%
    imap(
      ~ {
        attr(.x, "output_label") <- .y
        .x
      }
    )

  expect_output(
    Report_MetricCharts(lCharts),
    "#### Summary Charts \\{.tabset\\}"
  )
  expect_output(Report_MetricCharts(lCharts), "scatterPlot")
  expect_output(Report_MetricCharts(lCharts), "barChart")
  expect_output(Report_MetricCharts(lCharts), "timeSeries")
})

test_that("Handles some missing chart types (#53)", {
  lCharts <- list(
    scatterPlot = dummy_chart,
    timeSeries = dummy_chart
  ) %>%
    imap(
      ~ {
        attr(.x, "output_label") <- .y
        .x
      }
    )

  expect_output(
    Report_MetricCharts(lCharts),
    "#### Summary Charts \\{.tabset\\}"
  )
  expect_output(Report_MetricCharts(lCharts), "scatterPlot")
  expect_output(Report_MetricCharts(lCharts), "timeSeries")
})

test_that("Handles empty input (#53)", {
  lCharts <- list()

  expect_output(
    Report_MetricCharts(lCharts),
    "#### Summary Charts \\{.tabset\\}"
  )
  expect_output(Report_MetricCharts(lCharts), "#### {-}")
})

test_that("Output formatting and no errors (#53)", {
  lCharts <- list(
    scatterPlot = dummy_chart,
    barChart = dummy_chart
  ) %>%
    imap(
      ~ {
        attr(.x, "output_label") <- .y
        .x
      }
    )

  output <- capture.output(Report_MetricCharts(lCharts))
  expect_true(any(grepl("scatterPlot", output)))
  expect_true(any(grepl("barChart", output)))
  expect_true(any(grepl("<div class", output)))
  expect_true(any(grepl("</div>", output)))
})

test_that("Handles missing output_label (#53)", {
  lCharts <- list(
    scatterPlot = dummy_chart
  )

  expect_output(
    suppressMessages(Report_MetricCharts(lCharts)),
    "#### Summary Charts \\{.tabset\\}"
  )
  expect_output(suppressMessages(Report_MetricCharts(lCharts)), "scatterPlot")
})
