dfSubjects <- tibble::tibble(
  subjid = paste0("S", 1:4),
  studyid = "ST01",
  country = c("USA", "USA", "CAN", "CAN"),
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

test_that("pd_RandToDeathScatter returns a plotly object {#223}", {
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

test_that("pd_RandToDeathScatter degrades gracefully without treatment_related {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_degraded,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  expect_s3_class(p, "plotly")
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  expect_true(any(grepl("Treatment related: Unknown", texts)))
})

test_that("pd_RandToDeathScatter hover text shows all fields {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  s1 <- texts[grepl("Subject: S1", texts)]
  expect_match(s1, "Country: USA")
  expect_match(s1, "Site: INV-1")
  expect_match(s1, "Days to death: 20")
  expect_match(s1, "Bucket: <=30d")
  expect_match(s1, "Treatment related: Yes")
})

test_that("pd_RandToDeathScatter colors by bucket, not treatment_related {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid"
  )
  colors_used <- p$x$attrs[[1]]$colors
  expect_equal(unname(colors_used["<=30d"]), colorScheme("red", "dark"))
  expect_equal(unname(colors_used["31-90d"]), colorScheme("amber", "dark"))
})

test_that("pd_RandToDeathScatter validates inputs {#223}", {
  expect_error(
    pd_RandToDeathScatter(as.list(dfDeath_full), dfSubjects),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_RandToDeathScatter(dfDeath_full, dfSubjects, nWindowDays = 0),
    "nWindowDays must be a positive number"
  )
})

test_that("pd_RandToDeathScatter renders numeric rand-to-snapshot y at study level {#223}", {
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

test_that("pd_RandToDeathScatter requires death_dt when dSnapshotDate is supplied {#223}", {
  testthat::skip_if_not_installed("plotly")
  expect_error(
    pd_RandToDeathScatter(
      dfDeath_full,
      dfSubjects,
      strGroupCol = "studyid",
      dSnapshotDate = as.Date("2026-06-01")
    ),
    "dfDeath must contain death_dt when dSnapshotDate is supplied"
  )
})

test_that("pd_RandToDeathScatter tooltip shows NA for absent context columns {#223}", {
  testthat::skip_if_not_installed("plotly")
  # dfSubjects without `country` exercises the NA-backfill branch.
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dplyr::select(dfSubjects, -"country"),
    nWindowDays = 90,
    strGroupCol = "invid"
  )
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  expect_true(any(grepl("Country: NA", texts)))
})

test_that("pd_RandToDeathScatter builds a 2-D multicategory y when strOuterCol set {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site",
    strOuterCol = "country"
  )
  built <- plotly::plotly_build(p)
  tr <- built$x$data[[1]]
  expect_true(is.list(tr$y) && length(tr$y) == 2) # [[outer],[inner]]
  expect_true(all(tr$y[[1]] %in% c("USA", "CAN"))) # outer = country
})

test_that("pd_RandToDeathScatter labels a missing parent 'Unknown' {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dplyr::mutate(dfSubjects, country = NA_character_),
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  built <- plotly::plotly_build(p)
  outer <- unlist(lapply(built$x$data, function(d) d$y[[1]]))
  expect_true(all(outer == "Unknown"))
})

test_that("pd_RandToDeathScatter stays flat (categorical) when strOuterCol is NULL {#223}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_RandToDeathScatter(
    dfDeath_full,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid"
  )
  built <- plotly::plotly_build(p)
  expect_false(is.list(built$x$data[[1]]$y) && length(built$x$data[[1]]$y) == 2)
})

test_that("pd_RandToDeathScatter single-point multicategory y survives JSON auto-unboxing {#223}", {
  testthat::skip_if_not_installed("plotly")
  # Each bucket holds exactly one death, so list(Outer, Group) would auto-unbox
  # to a flat [outer, inner] once serialized, collapsing the 2-D y in the browser
  # (plotly_build keeps the R list, so only the JSON reveals it).
  dfSubjects_one <- tibble::tibble(
    subjid = c("S1", "S2"),
    invid = "INV-1",
    country = "USA",
    studyid = "ST01"
  )
  dfDeath_two <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_RandToDeathScatter(
    dfDeath_two,
    dfSubjects_one,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"y":[["USA"],["INV-1"]]', json, fixed = TRUE))
})

test_that("pd_RandToDeathScatter skips an empty bucket without error {#223}", {
  testthat::skip_if_not_installed("plotly")
  # A cohort confined to one bucket (both deaths <=30d) leaves the 31-Wd bucket
  # empty; add_markers errors on a zero-row trace, so the loop must skip it.
  dfSubjects_one <- tibble::tibble(
    subjid = c("S1", "S2"),
    invid = "INV-1",
    country = "USA",
    studyid = "ST01"
  )
  dfDeath_early <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(10, 20))
  p <- pd_RandToDeathScatter(
    dfDeath_early,
    dfSubjects_one,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_s3_class(p, "plotly")
  built <- plotly::plotly_build(p)
  # Only the populated <=30d bucket yields a trace.
  expect_length(built$x$data, 1)
})
