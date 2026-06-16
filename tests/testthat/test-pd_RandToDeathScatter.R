# Fixture: one subject per category, so every pd_CategoryLevels() entry is
# present and the scatter draws one trace each.
dfC <- tibble::tibble(
  subjid = c("A", "B", "C", "D", "E"),
  studyid = "ST01",
  country = c("USA", "USA", "CAN", "CAN", "USA"),
  invid = c("S1", "S1", "S2", "S2", "S1"),
  Category = factor(pd_CategoryLevels(90), levels = pd_CategoryLevels(90)),
  death_dy = c(20, 70, NA, NA, NA),
  discont_dy = c(NA, NA, 49, NA, NA),
  follow_up = c(200, 200, 200, 200, 40),
  x_anchor = c(20, 70, 49, 90, 40)
)

test_that("scatter plots all categories at x_anchor with fixed shared range {#247}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfC,
    nWindowDays = 90,
    vXRange = c(0, 95),
    vYRange = c(0, 210)
  )
  b <- plotly::plotly_build(p)

  # one trace per non-empty category
  expect_equal(length(b$x$data), 5)
  # fixed range is applied (AXIS-1)
  expect_equal(b$x$layout$xaxis$range, c(0, 95))
  expect_equal(b$x$layout$yaxis$range, c(0, 210))
  # per-point customdata carries [hover, country, invid] for JS filtering
  cd <- b$x$data[[1]]$customdata[[1]]
  expect_length(cd, 3)
})

test_that("scatter colors each category with pd_CategoryColors {#247}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(dfC, nWindowDays = 90)
  b <- plotly::plotly_build(p)
  cols <- pd_CategoryColors(90)
  # traces are added in pd_CategoryLevels order, so trace i has color i.
  expect_equal(b$x$data[[1]]$marker$color, unname(cols[1]))
  expect_equal(b$x$data[[5]]$marker$color, unname(cols[5]))
})

test_that("scatter hover carries subject / category / day fields {#247}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(dfC, nWindowDays = 90)
  b <- plotly::plotly_build(p)
  hover <- b$x$data[[1]]$customdata[[1]][[1]]
  expect_match(hover, "Subject: A")
  expect_match(hover, "Category: Death")
  expect_match(hover, "Follow-up: 200d")
})

test_that("scatter omits categories with no subjects {#247}", {
  testthat::skip_if_not_installed("plotly")
  dfTwo <- dfC[c(1, 4), ] # only "Death <=30d" and "Alive at 90 days"
  p <- pd_RandToDeathScatter(dfTwo, nWindowDays = 90)
  b <- plotly::plotly_build(p)
  expect_equal(length(b$x$data), 2)
})

test_that("scatter backfills NA country/site to empty string in customdata {#247}", {
  testthat::skip_if_not_installed("plotly")
  dfNA <- dfC[1, ]
  dfNA$country <- NA_character_
  dfNA$invid <- NA_character_
  p <- pd_RandToDeathScatter(dfNA, nWindowDays = 90)
  b <- plotly::plotly_build(p)
  cd <- b$x$data[[1]]$customdata[[1]]
  expect_equal(cd[[2]], "") # country
  expect_equal(cd[[3]], "") # invid
})

test_that("scatter autoranges when no fixed range is supplied {#247}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(dfC, nWindowDays = 90)
  # The unset range branch leaves xaxis$range unspecified in the layout we build.
  expect_null(p$x$layoutAttrs[[p$x$cur_data]]$xaxis$range)
  expect_s3_class(p, "plotly")
})

test_that("scatter returns an empty figure for an empty cohort {#247}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(dfC[0, ], nWindowDays = 90)
  expect_s3_class(p, "plotly")
})

test_that("scatter validates dfClassified is a data.frame {#247}", {
  expect_error(
    pd_RandToDeathScatter(as.list(dfC)),
    "dfClassified is not a data.frame"
  )
})
