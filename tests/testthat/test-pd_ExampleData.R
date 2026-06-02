# --- pd_MockCompleteDeathExtension ------------------------------------------
# S1: CTCAE grade-5 AE -> matched; reason term1, treatment-related.
# S2: grade-3 AE but ended on death date (<=1 day) -> matched; reason term2.
# S3: no qualifying AE -> falls back to compreas; not treatment-related.
dfDeath <- tibble::tibble(
  subjid = c("S1", "S2", "S3"),
  death_dt = as.Date(c("2026-02-15", "2026-03-01", "2026-04-01"))
)
dfAE <- tibble::tibble(
  subjid = c("S1", "S2", "S3"),
  aetoxgr = c(5, 3, 2),
  aeen_dt = as.Date(c(NA, "2026-03-01", "2026-01-01")),
  aest_dt = as.Date(c("2026-02-10", "2026-02-20", "2026-01-01")),
  mdrpt_nsv = c("term1", "term2", "term9"),
  aerel = c("Y", "N", NA)
)
dfStudComp <- tibble::tibble(
  subjid = c("S1", "S2", "S3"),
  compreas = c("Death", "Death", "Other")
)

test_that("pd_MockCompleteDeathExtension enriches Mapped_Death from fatal AE {#223}", {
  out <- pd_MockCompleteDeathExtension(dfDeath, dfAE, dfStudComp)
  expect_true(all(
    c("death_reason", "treatment_related", "ae_pt_at_death") %in% names(out)
  ))
  expect_equal(out$death_reason, c("Cardiac arrest", "Sepsis", "Other"))
  expect_equal(out$treatment_related, c(TRUE, FALSE, FALSE))
  expect_equal(out$ae_pt_at_death, c("term1", "term2", NA))
})

test_that("pd_MockCompleteDeathExtension compreas fallback is deterministic {#223}", {
  # S4: duplicate dfStudComp rows with non-Death reason ordered before Death;
  #     no qualifying AE -> fallback must prefer "Death" over "Discharged".
  # S5: no qualifying AE and missing compreas -> fallback must be "Unknown".
  dfDeath2 <- tibble::tibble(
    subjid = c("S4", "S5"),
    death_dt = as.Date(c("2026-05-01", "2026-06-01"))
  )
  dfAE2 <- tibble::tibble(
    subjid = character(0),
    aetoxgr = integer(0),
    aeen_dt = as.Date(character(0)),
    aest_dt = as.Date(character(0)),
    mdrpt_nsv = character(0),
    aerel = character(0)
  )
  # S4 has two rows: non-Death row intentionally listed first
  dfStudComp2 <- tibble::tibble(
    subjid = c("S4", "S4", "S5"),
    compreas = c("Discharged", "Death", NA_character_)
  )

  out <- pd_MockCompleteDeathExtension(dfDeath2, dfAE2, dfStudComp2)

  expect_equal(out$death_reason[out$subjid == "S4"], "Death")
  expect_equal(out$death_reason[out$subjid == "S5"], "Unknown")
  expect_equal(out$ae_pt_at_death, c(NA_character_, NA_character_))
  expect_equal(out$treatment_related, c(FALSE, FALSE))
})

# --- pd_SimulatePrematureDeathCohort ----------------------------------------
test_that("pd_SimulatePrematureDeathCohort returns a censored, schema-stable cohort {#223}", {
  dfSubj <- tibble::tibble(
    studyid = "ABC",
    subjid = paste0("S", seq_len(500))
  )
  snap <- as.Date("2026-06-01")
  out <- pd_SimulatePrematureDeathCohort(
    dfSubj,
    nWindowDays = 90,
    seed = 1,
    snapshot_date = snap
  )

  expect_s3_class(out, "tbl_df")
  expect_named(
    out,
    c(
      "studyid",
      "subjid",
      "death_dt",
      "death_dy",
      "death",
      "pd_date",
      "ae_pt_at_death",
      "compreas",
      "treatment_related",
      "death_reason"
    )
  )
  expect_gt(nrow(out), 0) # the seed must produce at least one observed death
  expect_true(all(out$death))
  expect_true(all(out$death_dy >= 1)) # only positive time-to-death observed
  expect_true(all(out$death_dt <= snap)) # censoring: no death after the snapshot
})

test_that("pd_SimulatePrematureDeathCohort is reproducible for a fixed seed {#223}", {
  dfSubj <- tibble::tibble(studyid = "ABC", subjid = paste0("S", seq_len(500)))
  snap <- as.Date("2026-06-01")
  a <- pd_SimulatePrematureDeathCohort(
    dfSubj,
    90,
    seed = 1,
    snapshot_date = snap
  )
  b <- pd_SimulatePrematureDeathCohort(
    dfSubj,
    90,
    seed = 1,
    snapshot_date = snap
  )
  expect_identical(a, b)
})
