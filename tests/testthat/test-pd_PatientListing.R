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

test_that("pd_PatientListing returns a DT htmlwidget {#59}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath)
  expect_s3_class(tbl, "datatables")
})

test_that("pd_PatientListing keeps only Flag==2 rows sorted by death_dy {#59}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_equal(df$subjid, c("S2", "S1")) # day 20 before day 50; S3 (Flag 0) dropped
  expect_equal(df$death_reason, c("Sepsis", "Cardiac arrest"))
})

test_that("pd_PatientListing degrades without reason/treatment columns {#59}", {
  df <- pd_PatientListingData(
    dfResults,
    dplyr::select(dfDeath, subjid, death_dt, death_dy)
  )
  expect_equal(df$death_reason, c("Unknown", "Unknown"))
  expect_true(all(is.na(df$treatment_related)))
})

test_that("pd_PatientListing validates inputs {#59}", {
  expect_error(
    pd_PatientListing(as.list(dfResults), dfDeath),
    "dfResults is not a data.frame"
  )
  expect_error(
    pd_PatientListing(dfResults, as.list(dfDeath)),
    "dfDeath is not a data.frame"
  )
})
