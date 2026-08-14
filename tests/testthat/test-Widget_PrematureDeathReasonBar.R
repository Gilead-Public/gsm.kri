reason_inputs <- function() {
  slice <- list(
    reason = c("Disease progression", "AE"),
    n = c(4L, 2L),
    hover = c(
      "Subjects: 4<br>% of premature deaths: 66.7%",
      "Subjects: 2<br>% of premature deaths: 33.3%"
    )
  )
  list(
    data = pd_ReasonRows(slice),
    spec = pd_ReasonBarSpec(),
    metadata = list(chartId = "pd-study-reasons", level = "study")
  )
}

test_that("Widget_PrematureDeathReasonBar returns a gsm.kri htmlwidget (#264)", {
  i <- reason_inputs()
  w <- Widget_PrematureDeathReasonBar(i$data, i$spec, i$metadata)
  expect_s3_class(w, c("Widget_PrematureDeathReasonBar", "htmlwidget"))
})

test_that("Widget_PrematureDeathReasonBar serializes horizontal spec + rows (#264)", {
  i <- reason_inputs()
  w <- Widget_PrematureDeathReasonBar(i$data, i$spec, i$metadata)
  spec_back <- jsonlite::fromJSON(w$x$spec, simplifyVector = FALSE)
  data_back <- jsonlite::fromJSON(w$x$data)
  expect_equal(spec_back$orientation, "horizontal")
  expect_true(all(c("reason", "n", "hover") %in% names(data_back)))
})

test_that("Widget_PrematureDeathReasonBar wires the pinned gsm.viz dependency (#264) (#291)", {
  i <- reason_inputs()
  w <- Widget_PrematureDeathReasonBar(i$data, i$spec, i$metadata)
  gv <- Filter(function(d) identical(d$name, "gsmViz"), w$dependencies)[[1]]
  expect_equal(as.character(gv$version), "2.4.1")
  expect_true(startsWith(gv$src$file, system.file(package = "gsm.vizr")))
})
