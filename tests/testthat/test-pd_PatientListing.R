dfResults <- tibble::tibble(
  GroupID = c("S1", "S2", "S3"),
  GroupLevel = "Subject",
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
  deathcls = c("Adverse Event", "Disease Progression")
)

test_that("pd_PatientListing returns a DT htmlwidget {#223}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath)
  expect_s3_class(tbl, "datatables")
})

test_that("pd_PatientListing keeps only Flag==2 rows sorted by death_dy {#223}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_equal(df$subjid, c("S2", "S1")) # day 20 before day 50; S3 (Flag 0) dropped
  expect_equal(df$death_reason, c("Disease Progression", "Adverse Event")) # deathcls, sorted S2(20),S1(50)
})

test_that("pd_PatientListing degrades to Unknown without deathcls {#223}", {
  df <- pd_PatientListingData(
    dfResults,
    dplyr::select(dfDeath, subjid, death_dt, death_dy)
  )
  expect_equal(df$death_reason, c("Unknown", "Unknown")) # no deathcls -> Unknown
  expect_true(all(df$treatment_related == "Unknown")) # no deathcls, no dfAE
})

test_that("pd_PatientListingData maps blank/whitespace deathcls to Unknown in both death_reason and treatment_related {#221}", {
  dfResultsBlank <- tibble::tibble(
    GroupID = c("E", "F", "G"),
    MetricID = "Analysis_pat0015",
    Flag = 2
  )
  dfDeathBlank <- tibble::tibble(
    subjid = c("E", "F", "G"),
    death_dt = as.Date("2026-02-01"),
    death_dy = c(10, 20, 30),
    deathcls = c(NA_character_, "", "   ")
  )
  out <- pd_PatientListingData(dfResultsBlank, dfDeathBlank)
  # Consistency the bug violated: a blank deathcls now renders "Unknown" in BOTH
  # columns (previously death_reason kept the blank while treatment_related said
  # "Unknown") -- both now route blank/whitespace through the same rule.
  expect_true(all(out$death_reason == "Unknown"))
  expect_true(all(out$treatment_related == "Unknown"))
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

test_that("Treatment Related is Yes only for AE death + fatal related AE {#248}", {
  dfResultsTR <- tibble::tibble(
    GroupID = c("A", "B", "C", "D"),
    MetricID = "Analysis_pat0015",
    Flag = 2
  )
  dfDeathTR <- tibble::tibble(
    subjid = c("A", "B", "C", "D"),
    death_dt = as.Date("2026-02-01"),
    death_dy = c(10, 20, 30, 40),
    deathcls = c("Adverse Event", "Adverse Event", "Disease Progression", "AE")
  )
  dfAETR <- tibble::tibble(
    subjid = c("A", "B", "D"),
    aetoxgr = c(5L, 5L, 4L),
    aerel = c("RELATED", "NOT RELATED", "RELATED")
  )
  out <- pd_PatientListingData(dfResultsTR, dfDeathTR, dfAE = dfAETR)
  tr <- stats::setNames(out$treatment_related, out$subjid)
  expect_equal(tr[["A"]], "Yes") # AE death + fatal(5) RELATED AE
  expect_equal(tr[["B"]], "No") # AE death + fatal(5) NOT RELATED AE -> No
  expect_equal(tr[["C"]], "No") # non-AE death + no qualifying AE (no AE row)
  expect_equal(tr[["D"]], "Unknown") # AE death but AE grade 4 (not fatal)
})

test_that("Treatment Related is Unknown when deathcls missing {#248}", {
  dfResultsTR <- tibble::tibble(
    GroupID = c("E", "F"),
    MetricID = "Analysis_pat0015",
    Flag = 2
  )
  dfDeathTR <- tibble::tibble(
    subjid = c("E", "F"),
    death_dt = as.Date("2026-02-01"),
    death_dy = c(10, 20),
    deathcls = c(NA_character_, "")
  )
  dfAETR <- tibble::tibble(subjid = "E", aetoxgr = 5L, aerel = "RELATED")
  out <- pd_PatientListingData(dfResultsTR, dfDeathTR, dfAE = dfAETR)
  expect_true(all(out$treatment_related == "Unknown")) # deathcls missing/blank
})

test_that("Treatment Related non-AE death with a fatal related AE is Unknown {#248}", {
  dfResultsTR <- tibble::tibble(
    GroupID = "G",
    MetricID = "Analysis_pat0015",
    Flag = 2
  )
  dfDeathTR <- tibble::tibble(
    subjid = "G",
    death_dt = as.Date("2026-02-01"),
    death_dy = 10,
    deathcls = "Disease Progression"
  )
  dfAETR <- tibble::tibble(subjid = "G", aetoxgr = 5L, aerel = "RELATED")
  out <- pd_PatientListingData(dfResultsTR, dfDeathTR, dfAE = dfAETR)
  expect_equal(out$treatment_related, "Unknown") # contradictory -> Unknown
})

test_that("Treatment Related AE death with a fatal NOT RELATED AE is No {#248}", {
  dfResultsTR <- tibble::tibble(
    GroupID = "H",
    MetricID = "Analysis_pat0015",
    Flag = 2
  )
  dfDeathTR <- tibble::tibble(
    subjid = "H",
    death_dt = as.Date("2026-02-01"),
    death_dy = 10,
    deathcls = "Adverse Event"
  )
  dfAETR <- tibble::tibble(subjid = "H", aetoxgr = 5L, aerel = "NOT RELATED")
  out <- pd_PatientListingData(dfResultsTR, dfDeathTR, dfAE = dfAETR)
  expect_equal(out$treatment_related, "No") # AE death + fatal(5) NOT RELATED AE
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
      "randomization_date",
      "death_dt",
      "death_dy",
      "death_reason",
      "treatment_related"
    )
  )
})

test_that("pd_PatientListingData derives randomization_date as death_dt - death_dy {#221}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_s3_class(df$randomization_date, "Date")
  # Rows are sorted by death_dy asc: S2 (20) then S1 (50).
  expect_equal(
    df$randomization_date,
    as.Date(c("2026-03-01", "2026-02-15")) - c(20, 50)
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

dfSubjectsStudy <- tibble::tibble(
  subjid = c("S1", "S2", "S3"),
  studyid = "STUDY-X",
  invid = c("INV-1", "INV-1", "INV-2"),
  country = c("USA", "USA", "CAN")
)

test_that("pd_PatientListingData includes studyid when dfSubjects has it {#221}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjectsStudy)
  expect_true("studyid" %in% names(df))
  expect_equal(df$studyid, c("STUDY-X", "STUDY-X"))
})

test_that("pd_PatientListingData omits studyid when dfSubjects lacks it {#221}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjects)
  expect_false("studyid" %in% names(df))
  expect_true("randomization_date" %in% names(df))
})

test_that("pd_PatientListingData joins studyid even when dfSubjects has no invid {#221}", {
  dfSubjectsNoInvid <- tibble::tibble(
    subjid = c("S1", "S2", "S3"),
    studyid = "STUDY-X"
  )
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjectsNoInvid)
  expect_true("studyid" %in% names(df))
  expect_equal(df$studyid, c("STUDY-X", "STUDY-X"))
  expect_false("invid" %in% names(df))
})

test_that("pd_PatientListingData puts Study first, Rand Date before Death Date {#221}", {
  df <- pd_PatientListingData(dfResults, dfDeath, dfSubjectsStudy)
  expect_equal(
    names(df),
    c(
      "studyid",
      "subjid",
      "country",
      "invid",
      "randomization_date",
      "death_dt",
      "death_dy",
      "death_reason",
      "treatment_related"
    )
  )
})

test_that("pd_PatientListing labels Study and Randomization Date columns {#221}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath, dfSubjectsStudy)
  header <- paste(as.character(tbl$x$container), collapse = " ")
  expect_match(header, "Study", fixed = TRUE)
  expect_match(header, "Randomization Date", fixed = TRUE)
})

test_that("pd_PatientListingData yields NA randomization_date when death data missing {#221}", {
  dfResultsMissing <- tibble::tibble(
    GroupID = "S9",
    GroupLevel = "Subject",
    MetricID = "Analysis_pat0015",
    Numerator = 1,
    Denominator = 1,
    Score = 1,
    Flag = 2,
    SnapshotDate = as.Date("2026-05-01")
  )
  df <- pd_PatientListingData(dfResultsMissing, dfDeath) # S9 absent from dfDeath
  expect_true(is.na(df$randomization_date))
})

# --- Eligibility status (#249) ---------------------------------------------
dfResultsElig <- tibble::tibble(
  GroupID = c("E1", "E2", "E3", "E4", "E5"),
  MetricID = "Analysis_pat0015",
  Flag = 2
)
dfDeathElig <- tibble::tibble(
  subjid = c("E1", "E2", "E3", "E4", "E5"),
  death_dt = as.Date("2026-02-01"),
  death_dy = c(10, 20, 30, 40, 50)
)
dfExclusionElig <- tibble::tibble(
  # E5 deliberately absent from the exclusion frame -> Unknown
  subjid = c("E1", "E2", "E3", "E4"),
  Source = c(
    "Neither",
    "EDC I/E only",
    "Eligibility PD only",
    "Ineligible, Both Criteria"
  )
)

test_that("eligibility_status maps Source via the kri0014 rule {#249}", {
  out <- pd_PatientListingData(
    dfResultsElig,
    dfDeathElig,
    dfSubjects = NULL,
    dfExclusion = dfExclusionElig
  )
  es <- setNames(out$eligibility_status, out$subjid)
  expect_equal(es[["E1"]], "Eligible") # Source == 'Neither'
  expect_equal(es[["E2"]], "Ineligible") # EDC I/E only
  expect_equal(es[["E3"]], "Ineligible") # Eligibility PD only (ie_violation is NULL!)
  expect_equal(es[["E4"]], "Ineligible") # Ineligible, Both Criteria
  expect_equal(es[["E5"]], "Unknown") # no row in Mapped_EXCLUSION
})

test_that("eligibility_status column is omitted without dfExclusion {#249}", {
  df <- pd_PatientListingData(dfResults, dfDeath)
  expect_false("eligibility_status" %in% names(df))
})

test_that("eligibility_status column is omitted when Source is absent {#249}", {
  df <- pd_PatientListingData(
    dfResults,
    dfDeath,
    dfExclusion = tibble::tibble(subjid = "S1")
  )
  expect_false("eligibility_status" %in% names(df))
})

test_that("eligibility_status is the rightmost column {#249}", {
  out <- pd_PatientListingData(
    dfResultsElig,
    dfDeathElig,
    dfSubjects = NULL,
    dfExclusion = dfExclusionElig
  )
  expect_equal(utils::tail(names(out), 1), "eligibility_status")
})

test_that("pd_PatientListing labels the Eligibility Status column {#249}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(
    dfResultsElig,
    dfDeathElig,
    dfSubjects = NULL,
    dfExclusion = dfExclusionElig
  )
  header <- paste(as.character(tbl$x$container), collapse = " ")
  expect_match(header, "Eligibility Status", fixed = TRUE)
})

test_that("pd_PatientListing omits Eligibility Status without dfExclusion {#249}", {
  testthat::skip_if_not_installed("DT")
  tbl <- pd_PatientListing(dfResults, dfDeath)
  header <- paste(as.character(tbl$x$container), collapse = " ")
  expect_no_match(header, "Eligibility Status", fixed = TRUE)
})
