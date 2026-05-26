dfDeath_full <- tibble::tibble(
  subjid = c("S1", "S2", "S3", "S4"),
  death_dy = c(20, 50, 80, 120),
  death_reason = c(
    "Cardiac arrest",
    "Cardiac arrest",
    "Sepsis",
    "Cardiac arrest"
  )
)
dfDeath_degraded <- dplyr::select(dfDeath_full, subjid, death_dy)

test_that("pd_ReasonDist returns a plotly object {#59}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_ReasonDist(dfDeath_full, nWindowDays = 90)
  expect_s3_class(p, "plotly")
})

test_that("pd_ReasonDist counts only premature deaths {#59}", {
  df <- pd_ReasonCounts(dfDeath_full, nWindowDays = 90)
  expect_equal(df$n[df$death_reason == "Cardiac arrest"], 2) # S1, S2 (S4 is day 120, excluded)
  expect_equal(df$n[df$death_reason == "Sepsis"], 1)
})

test_that("pd_ReasonDist degrades to Unknown without death_reason {#59}", {
  df <- pd_ReasonCounts(dfDeath_degraded, nWindowDays = 90)
  expect_equal(df$death_reason, "Unknown")
  expect_equal(df$n, 3) # S1, S2, S3 within window
})

test_that("pd_ReasonDist validates inputs {#59}", {
  expect_error(
    pd_ReasonDist(as.list(dfDeath_full)),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_ReasonDist(dfDeath_full, nWindowDays = -5),
    "nWindowDays must be a positive number"
  )
})
