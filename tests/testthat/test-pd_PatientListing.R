dfResults <- tibble::tibble(
  GroupID = c("S1", "S2", "S3"),
  GroupLevel = "Patient",
  MetricID = "Analysis_pat0015",
  Numerator = c(1, 1, 0),
  Denominator = 1,
  Score = c(1, 1, 0),
  Flag = c(2, 2, 0),
  SnapshotDate = as.Date("2026-05-01")
)
dfDeath <- tibble::tibble(
  subjid = c("S1", "S2"),
  death_dt = as.Date(c("2026-02-15", "2026-03-01")),
  death_dy = c(50, 20),
  death_reason = c("Cardiac arrest", "Sepsis"),
  treatment_related = c(TRUE, FALSE)
)

test_that("pd_PatientListing returns a DT htmlwidget {#223}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath)
  expect_s3_class(tbl, "datatables")
})

test_that("pd_PatientListing keeps only Flag==2 rows sorted by death_dy {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_equal(df$subjid, c("S2", "S1")) # day 20 before day 50; S3 (Flag 0) dropped
  expect_equal(df$death_reason, c("Sepsis", "Cardiac arrest"))
})

test_that("pd_PatientListing degrades without reason/treatment columns {#223}", {
  df <- pd_PatientListingData(
    dfResults,
    dplyr::select(dfDeath, subjid, death_dt, death_dy)
  )
  expect_equal(df$death_reason, c("Unknown", "Unknown"))
  expect_true(all(is.na(df$treatment_related)))
})

test_that("pd_PatientListing validates inputs {#223}", {
  expect_error(
    pd_PatientListing(as.list(dfResults), dfDeath),
    "dfResults is not a data.frame"
  )
  expect_error(
    pd_PatientListing(dfResults, as.list(dfDeath)),
    "dfDeath is not a data.frame"
  )
})

dfSubjects <- tibble::tibble(
  subjid = c("S1", "S2", "S3"),
  invid = c("INV-1", "INV-1", "INV-2"),
  country = c("USA", "USA", "CAN")
)

test_that("pd_PatientListingData includes invid when dfSubjects provided {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjects)
  expect_true("invid" %in% names(df))
  expect_equal(df$invid, c("INV-1", "INV-1")) # S2 (day 20), S1 (day 50) — both Flag==2
})

test_that("pd_PatientListingData works without dfSubjects (backwards compat) {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_false("invid" %in% names(df))
  expect_equal(nrow(df), 2)
})

test_that("pd_CheckWindowConsistency warns on mismatch {#223}", {
  expect_warning(
    pd_CheckWindowConsistency(10, 0, 2),
    "disagrees with the window used to produce dfResults"
  )
  expect_null(suppressWarnings(pd_CheckWindowConsistency(10, 0, 2)))
})

test_that("pd_PatientListingData joins country when dfSubjects has it {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjects)
  expect_true("country" %in% names(df))
  expect_equal(df$country, c("USA", "USA")) # S2 (day 20), S1 (day 50)
})

test_that("pd_PatientListingData orders identity columns first {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjects)
  expect_equal(
    names(df),
    c(
      "subjid",
      "country",
      "invid",
      "death_dt",
      "death_dy",
      "death_reason",
      "treatment_related"
    )
  )
})

test_that("pd_PatientListingData drops the constant Flag column {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_false("Flag" %in% names(df))
})

test_that("pd_PatientListing names the invid column for the JS filter {#223}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath, dfSubjects)
  defs <- tbl$x$options$columnDefs
  has_invid_name <- any(vapply(
    defs,
    function(d) identical(d$name, "invid"),
    logical(1)
  ))
  expect_true(has_invid_name)
})

test_that("pd_PatientListing exposes a CSV download button {#223}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath, dfSubjects)
  expect_true("Buttons" %in% unlist(tbl$x$extensions))
  buttons <- tbl$x$options$buttons
  has_csv <- any(vapply(
    buttons,
    function(b) identical(b$extend, "csv"),
    logical(1)
  ))
  expect_true(has_csv)
  # dom keeps "l" so the "Show N entries" length menu survives the button bar
  expect_match(tbl$x$options$dom, "l")
})

test_that("pd_PatientListing sorts by death_dy via a name-derived index {#223}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath, dfSubjects)
  sort_target <- tbl$x$options$order[[1]][[1]]
  expect_equal(sort_target, which(names(tbl$x$data) == "death_dy") - 1L)
})
