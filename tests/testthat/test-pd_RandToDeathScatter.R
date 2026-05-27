dfSubjects <- tibble::tibble(
  subjid = paste0("S", 1:4),
  invid = c("INV-1", "INV-1", "INV-2", "INV-2")
)
dfDeath_full <- tibble::tibble(
  subjid = c("S1", "S2", "S4"),
  death_dy = c(20, 50, 120),
  treatment_related = c(TRUE, FALSE, TRUE)
)
dfDeath_degraded <- dplyr::select(dfDeath_full, subjid, death_dy)
dfDeath_dated <- dplyr::mutate(
  dfDeath_full,
  death_dt = as.Date("2026-01-01") + .data$death_dy
)

test_that("pd_RandToDeathScatter returns a plotly object with treatment_related {#59}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  expect_s3_class(p, "plotly")
})

test_that("pd_RandToDeathScatter degrades gracefully without treatment_related {#59}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_degraded,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  expect_s3_class(p, "plotly")
})

test_that("pd_RandToDeathScatter validates inputs {#59}", {
  expect_error(
    pd_RandToDeathScatter(as.list(dfDeath_full), dfSubjects),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_RandToDeathScatter(dfDeath_full, dfSubjects, nWindowDays = 0),
    "nWindowDays must be a positive number"
  )
})

test_that("pd_RandToDeathScatter renders numeric rand-to-snapshot y with dSnapshotDate", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_dated,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "studyid",
    strGroupLabel = "Study",
    dSnapshotDate = as.Date("2026-06-01")
  )
  expect_s3_class(p, "plotly")
})

test_that("pd_RandToDeathScatter requires death_dt when dSnapshotDate is supplied", {
  testthat::skip_if_not_installed("plotly")
  expect_error(
    pd_RandToDeathScatter(
      dfDeath_full,
      dfSubjects,
      dSnapshotDate = as.Date("2026-06-01")
    ),
    "dfDeath must contain death_dt when dSnapshotDate is supplied"
  )
})
