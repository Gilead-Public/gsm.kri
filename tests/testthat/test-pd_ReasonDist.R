dfDeath_full <- tibble::tibble(
  subjid = c("S1", "S2", "S3", "S4"),
  death_dy = c(20, 50, 80, 120),
  deathcls = c(
    "Adverse Event",
    "Adverse Event",
    "Disease Progression",
    "Adverse Event"
  )
)
dfDeath_degraded <- dplyr::select(dfDeath_full, subjid, death_dy)

test_that("pd_ReasonDist returns a plotly object {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_ReasonDist(dfDeath_full, nWindowDays = 90)
  expect_s3_class(p, "plotly")
})

test_that("pd_ReasonDist counts only premature deaths {#223}", {
  df <- pd_ReasonCounts(dfDeath_full, nWindowDays = 90)
  expect_equal(df$n[df$death_reason == "Adverse Event"], 2) # S1, S2 (S4 day120 excluded)
  expect_equal(df$n[df$death_reason == "Disease Progression"], 1)
})

test_that("pd_ReasonDist degrades to Unknown without deathcls {#223}", {
  df <- pd_ReasonCounts(dfDeath_degraded, nWindowDays = 90)
  expect_equal(df$death_reason, "Unknown")
  expect_equal(df$n, 3) # S1, S2, S3 within window
})

test_that("pd_ReasonDist validates inputs {#223}", {
  expect_error(
    pd_ReasonDist(as.list(dfDeath_full)),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_ReasonDist(dfDeath_full, nWindowDays = -5),
    "nWindowDays must be a positive number"
  )
})

test_that("pd_ReasonDist hover text shows count and both percentages {#223}", {
  testthat::skip_if_not_installed("plotly")
  # premature (<=90): S1, S2 (Adverse Event), S3 (Disease Progression); S4 @120 excluded.
  p <- pd_ReasonDist(dfDeath_full, nWindowDays = 90, nEnrolled = 10)
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  expect_true(any(grepl("Reason: Adverse Event", texts)))
  expect_true(any(grepl("% of enrolled: 20.0%", texts))) # 2 / 10
  expect_true(any(grepl("% of premature deaths: 66.7%", texts))) # 2 / 3
})

test_that("pd_ReasonDist labels each bar with its count {#223}", {
  testthat::skip_if_not_installed("plotly")
  # premature (<=90): Adverse Event = 2 (S1, S2), Disease Progression = 1 (S3).
  p <- pd_ReasonDist(dfDeath_full, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  expect_setequal(as.character(built$x$data[[1]]$text), c("2", "1"))
})

test_that("pd_ReasonDist omits enrolled percent when nEnrolled is NULL {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_ReasonDist(dfDeath_full, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  expect_false(any(grepl("% of enrolled", texts)))
  expect_true(any(grepl("% of premature deaths", texts)))
})

test_that("pd_ReasonByCountry groups reasons per country with an __ALL__ aggregate {#254}", {
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    death_dy = c(20, 50, 80, 120),
    deathcls = c(
      "Adverse Event",
      "Adverse Event",
      "Disease Progression",
      "Adverse Event"
    )
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    country = c("USA", "CAN", "USA", "USA")
  )
  res <- pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)
  expect_setequal(names(res), c("USA", "CAN", "__ALL__")) # S4 @120 excluded
  expect_equal(sum(res[["USA"]]$n), 2) # S1 (AE), S3 (DP)
  expect_setequal(
    res[["USA"]]$reason,
    c("Adverse Event", "Disease Progression")
  )
  expect_equal(sum(res[["__ALL__"]]$n), 3) # S1, S2, S3
  expect_equal(res[["__ALL__"]]$reason[1], "Adverse Event") # sorted desc (AE=2)
  expect_match(res[["__ALL__"]]$hover[1], "% of premature deaths")
})

test_that("pd_ReasonByCountry falls back to Unknown reason and country {#254}", {
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(10, 20)) # no deathcls
  dfSubjects <- tibble::tibble(subjid = "S1", country = "USA") # S2 no country
  res <- pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)
  expect_true("Unknown" %in% names(res)) # S2 unknown country
  expect_equal(res[["__ALL__"]]$reason, "Unknown") # no deathcls
  expect_equal(sum(res[["__ALL__"]]$n), 2)
})

test_that("pd_ReasonByCountry validates dfDeath {#254}", {
  expect_error(
    pd_ReasonByCountry(
      as.list(dfDeath_full),
      tibble::tibble(subjid = "S1", country = "USA")
    ),
    "dfDeath is not a data.frame"
  )
})

test_that("pd_ReasonByCountry falls back to Unknown country when dfSubjects is NULL {#254}", {
  res <- pd_ReasonByCountry(dfDeath_full, dfSubjects = NULL, nWindowDays = 90)
  expect_setequal(names(res), c("Unknown", "__ALL__"))
  expect_equal(sum(res[["__ALL__"]]$n), 3)
})
