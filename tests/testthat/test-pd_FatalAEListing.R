dfResultsFatal <- tibble::tibble(
  GroupID = c("P1", "P2", "P3", "N1"),
  GroupLevel = "Subject",
  MetricID = "Analysis_pat0015",
  Flag = c(2, 2, 2, 0)
)

dfSubjectsFatal <- tibble::tibble(
  studyid = "ST01",
  subjid = c("P1", "P2", "P3", "N1"),
  invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
  country = c("USA", "USA", "CAN", "CAN")
)

dfAEFatal <- tibble::tibble(
  studyid = "ST01",
  subjid = c("P1", "P1", "P1", "P2", "P3", "N1"),
  mdrpt_nsv = c("Cardiac arrest", "Sepsis", "Headache", "Nausea", "Respiratory failure", "Sepsis"),
  aest_dt = as.Date(c("2026-02-10", "2026-02-12", "2026-01-05", "2026-01-20", "2026-03-01", "2026-02-01")),
  aetoxgr = c(5L, 4L, 1L, 2L, 5L, 5L),
  aeout = c("Fatal", "Fatal", "Recovered/Resolved", "Recovered/Resolved", NA, "Fatal"),
  aesdth = c("Yes", "Yes", "No", "No", NA, "Yes"),
  aereldrv = c("Yes", "No", "No", "No", NA, "Yes"),
  aerel = NA_character_,
  # Never shown: protocol-sensitive fields must not reach the listing.
  DEATHCAU = "Cardiac",
  cmtrt = "Drug X"
)

test_that("pd_FatalAEListingData keeps one row per qualifying fatal AE (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal, dfSubjectsFatal)

  # P1 has two qualifying AEs (grade 5 + Fatal; Fatal outcome only), P2 none,
  # P3 one (grade 5 with missing outcome).
  expect_equal(nrow(out), 3L)
  expect_equal(out$subjid, c("P1", "P1", "P3"))
  expect_equal(out$mdrpt_nsv, c("Cardiac arrest", "Sepsis", "Respiratory failure"))
})

test_that("pd_FatalAEListingData carries study, country, site and the AE term (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal, dfSubjectsFatal)

  expect_equal(
    names(out),
    c("studyid", "subjid", "country", "invid", "mdrpt_nsv", "aest_dt", "aeout", "treatment_related")
  )
  expect_equal(out$studyid, rep("ST01", 3))
  expect_equal(out$invid, c("INV-1", "INV-1", "INV-2"))
  expect_equal(out$country, c("USA", "USA", "CAN"))
})

test_that("pd_FatalAEListingData excludes protocol-sensitive fields (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal, dfSubjectsFatal)
  expect_false(any(c("DEATHCAU", "cmtrt", "aerel", "aetoxgr", "aesdth", "aereldrv") %in% names(out)))
})

test_that("pd_FatalAEListingData excludes participants outside the premature-death population (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal, dfSubjectsFatal)
  # N1 has a fatal AE but is not a flagged premature death.
  expect_false("N1" %in% out$subjid)
})

test_that("pd_FatalAEListingData renders missing relatedness and outcome as Unknown (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal, dfSubjectsFatal)
  expect_equal(out$treatment_related, c("Yes", "No", "Unknown"))
  expect_equal(out$aeout, c("Fatal", "Fatal", "Unknown"))
})

test_that("pd_FatalAEListingData falls back to aerel when aereldrv is absent (#304)", {
  dfAE <- tibble::tibble(
    subjid = c("P1", "P2"),
    aetoxgr = 5L,
    aerel = c("RELATED", "NOT RELATED")
  )
  out <- pd_FatalAEListingData(dfResultsFatal, dfAE)
  expect_equal(out$treatment_related, c("Yes", "No"))
})

test_that("pd_FatalAEListingData returns a zero-row listing when nothing qualifies (#304)", {
  dfAE <- dplyr::filter(dfAEFatal, .data$subjid == "P2")
  out <- pd_FatalAEListingData(dfResultsFatal, dfAE, dfSubjectsFatal)
  expect_equal(nrow(out), 0L)
  expect_true(all(c("subjid", "mdrpt_nsv", "treatment_related") %in% names(out)))

  no_ae <- pd_FatalAEListingData(dfResultsFatal, NULL, dfSubjectsFatal)
  expect_equal(nrow(no_ae), 0L)
  expect_true(all(c("subjid", "mdrpt_nsv", "treatment_related") %in% names(no_ae)))
})

test_that("pd_FatalAEListingData works without dfSubjects (#304)", {
  out <- pd_FatalAEListingData(dfResultsFatal, dfAEFatal)
  expect_equal(nrow(out), 3L)
  expect_false(any(c("invid", "country") %in% names(out)))
  # studyid comes from the AE data when no subject data is supplied.
  expect_equal(out$studyid, rep("ST01", 3))
})

test_that("pd_FatalAEListingData validates inputs (#304)", {
  expect_error(
    pd_FatalAEListingData(as.list(dfResultsFatal), dfAEFatal),
    "dfResults is not a data.frame"
  )
  expect_error(
    pd_FatalAEListingData(dfResultsFatal, as.list(dfAEFatal)),
    "dfAE is not a data.frame"
  )
})

test_that("pd_FatalAEListing returns a DT widget with a named invid column (#304)", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_FatalAEListing(dfResultsFatal, dfAEFatal, dfSubjectsFatal)
  expect_s3_class(tbl, "datatables")
  defs <- tbl$x$options$columnDefs
  expect_true(any(vapply(defs, function(d) identical(d$name, "invid"), logical(1))))
})

test_that("pd_FatalAEListing renders an empty table when nothing qualifies (#304)", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_FatalAEListing(dfResultsFatal, NULL, dfSubjectsFatal)
  expect_s3_class(tbl, "datatables")
})
