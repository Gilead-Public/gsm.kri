ipc_scatter_data <- function() {
  testthat::skip_if_not_installed("plotly")
  df <- ipc_classified()
  p <- ipc_TimeToEventScatter(
    df,
    max(c(df$days_since_enrl, df$days_to_event), na.rm = TRUE),
    "ipc-study-tte"
  )
  list(widget = p, built = plotly::plotly_build(p)$x)
}

test_that("one trace per status; the legend follows the stack order (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  names <- vapply(traces, `[[`, "", "name")
  ranks <- vapply(traces, `[[`, 0, "legendrank")
  expect_setequal(names, names(ipc_StatusColors()))
  expect_equal(names[order(ranks)], names(ipc_StatusColors()))
})

test_that("not-dosed statuses draw over the dosed ones (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  names <- vapply(traces, `[[`, "", "name")
  expect_lt(
    max(match(
      c("Study complete", "Premature treatment discontinuation", "Ongoing"),
      names
    )),
    min(match(
      c("Potential IP non-starter - within window", "Confirmed IP non-starter"),
      names
    ))
  )
})

test_that("squares mark dosed participants, circles the rest (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  by_name <- stats::setNames(traces, vapply(traces, `[[`, "", "name"))
  expect_true(all(by_name[["Ongoing"]]$marker$symbol == "square"))
  expect_true(all(
    by_name[["Confirmed IP non-starter"]]$marker$symbol == "circle"
  ))
})

test_that("customdata carries subjid, invid, country and dosed per point (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  ongoing <- traces[[which(vapply(traces, `[[`, "", "name") == "Ongoing")]]
  first <- ongoing$customdata[[1]]
  expect_equal(unlist(first), c("P01", "JP01", "Japan", "Y"))
})

test_that("participants without an event sit on the diagonal (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  ongoing <- traces[[which(vapply(traces, `[[`, "", "name") == "Ongoing")]]
  expect_equal(unlist(ongoing$x), unlist(ongoing$y))
})

test_that("a participant without an enrollment date is left off (#320)", {
  traces <- Filter(function(t) !is.null(t$name), ipc_scatter_data()$built$data)
  ids <- unlist(lapply(traces, function(t) {
    vapply(t$customdata, function(cd) cd[[1]], "")
  }))
  expect_false("P23" %in% ids)
  expect_length(ids, 23)
})

test_that("both axes share one range with a dashed diagonal (#320)", {
  layout <- ipc_scatter_data()$built$layout
  expect_equal(layout$xaxis$range, layout$yaxis$range)
  # P24's event predates enrollment, so the range reaches below 0.
  expect_lt(layout$xaxis$range[[1]], -8)
  expect_equal(layout$shapes[[1]]$line$dash, "dash")
  expect_equal(layout$shapes[[1]]$x1, layout$xaxis$range[[2]])
})

test_that("the scatter registers with the filter script on render (#320)", {
  hooks <- ipc_scatter_data()$widget$jsHooks$render
  expect_length(hooks, 1)
  expect_match(hooks[[1]]$code, "ipcRegisterScatter", fixed = TRUE)
  expect_equal(hooks[[1]]$data, "ipc-study-tte")
})
