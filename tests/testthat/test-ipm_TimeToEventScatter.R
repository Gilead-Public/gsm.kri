ipm_scatter_data <- function() {
  testthat::skip_if_not_installed("plotly")
  df <- ipm_classified()
  p <- ipm_TimeToEventScatter(
    df,
    max(c(df$days_since_enrl, df$days_to_event), na.rm = TRUE),
    "ipc-study-tte"
  )
  list(widget = p, built = plotly::plotly_build(p)$x)
}

test_that("one trace per status; the legend follows the stack order (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  names <- vapply(traces, `[[`, "", "name")
  ranks <- vapply(traces, `[[`, 0, "legendrank")
  expect_setequal(names, names(ipm_StatusColors()))
  expect_equal(names[order(ranks)], names(ipm_StatusColors()))
})

test_that("not-dosed statuses draw over the dosed ones (#320, #332)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  names <- vapply(traces, `[[`, "", "name")
  expect_lt(
    max(match(
      c(
        "Treatment complete per protocol",
        "Premature treatment discontinuation",
        "Potential premature treatment discontinuation",
        "Treatment ongoing"
      ),
      names
    )),
    min(match(
      c("Potential IP non-starter - within window", "Confirmed IP non-starter"),
      names
    ))
  )
})

test_that("squares mark dosed participants, circles the rest (#320, #332)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  by_name <- stats::setNames(traces, vapply(traces, `[[`, "", "name"))
  for (status in c(
    "Treatment complete per protocol",
    "Premature treatment discontinuation",
    "Potential premature treatment discontinuation",
    "Treatment ongoing"
  )) {
    symbols <- by_name[[status]]$marker$symbol
    expect_gt(length(symbols), 0, label = status)
    expect_true(all(symbols == "square"), label = status)
  }
  expect_true(all(
    by_name[["Confirmed IP non-starter"]]$marker$symbol == "circle"
  ))
})

test_that("customdata carries subjid, invid, country and dosed per point (#320, #332)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  ongoing <- traces[[which(vapply(traces, `[[`, "", "name") == "Treatment ongoing")]]
  first <- ongoing$customdata[[1]]
  expect_equal(unlist(first), c("P01", "JP01", "Japan", "Y"))
})

test_that("participants without an event sit on the diagonal (#320, #332)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  ongoing <- traces[[which(vapply(traces, `[[`, "", "name") == "Treatment ongoing")]]
  ids <- vapply(ongoing$customdata, function(cd) cd[[1]], "")
  x <- unlist(ongoing$x)
  y <- unlist(ongoing$y)
  # P28 has a discontinuation date, so it sits above the diagonal.
  expect_equal(x[ids != "P28"], y[ids != "P28"])
  expect_lt(x[ids == "P28"], y[ids == "P28"])
})

test_that("a participant without an enrollment date is left off (#320, #332)", {
  traces <- Filter(function(t) !is.null(t$name), ipm_scatter_data()$built$data)
  ids <- unlist(lapply(traces, function(t) {
    vapply(t$customdata, function(cd) cd[[1]], "")
  }))
  expect_false("P23" %in% ids)
  expect_length(ids, 28)
})

test_that("both axes share one range with a dashed diagonal (#320)", {
  layout <- ipm_scatter_data()$built$layout
  expect_equal(layout$xaxis$range, layout$yaxis$range)
  # P24's event predates enrollment, so the range reaches below 0.
  expect_lt(layout$xaxis$range[[1]], -8)
  expect_equal(layout$shapes[[1]]$line$dash, "dash")
  expect_equal(layout$shapes[[1]]$x1, layout$xaxis$range[[2]])
})

test_that("the scatter registers with the filter script on render (#320)", {
  hooks <- ipm_scatter_data()$widget$jsHooks$render
  expect_length(hooks, 1)
  expect_match(hooks[[1]]$code, "ipcRegisterScatter", fixed = TRUE)
  expect_equal(hooks[[1]]$data, "ipc-study-tte")
})
