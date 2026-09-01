# --- pd_SimulatePrematureDeathCohort ----------------------------------------
test_that("simulation exposes rgmn_dt and a studcomp frame for all subjects {#246}", {
  subj <- tibble::tibble(studyid = "ST01", subjid = paste0("S", 1:50))
  sim <- pd_SimulatePrematureDeathCohort(
    subj,
    nWindowDays = 90,
    snapshot_date = as.Date("2026-05-01")
  )
  expect_true(all(
    c("Mapped_Death", "Mapped_SUBJ", "Mapped_STUDCOMP", "Mapped_AE") %in%
      names(sim)
  ))
  expect_true("rgmn_dt" %in% names(sim$Mapped_SUBJ))
  expect_equal(nrow(sim$Mapped_SUBJ), 50)
  expect_true("deathcls" %in% names(sim$Mapped_Death))
  expect_false(any(c("aerel", "death_reason") %in% names(sim$Mapped_Death)))
  expect_true(all(c("subjid", "aetoxgr", "aerel") %in% names(sim$Mapped_AE)))
})

test_that("pd_SimulatePrematureDeathCohort returns a censored, schema-stable death frame {#246}", {
  dfSubj <- tibble::tibble(
    studyid = "ABC",
    subjid = paste0("S", seq_len(500))
  )
  snap <- as.Date("2026-06-01")
  sim <- pd_SimulatePrematureDeathCohort(
    dfSubj,
    nWindowDays = 90,
    seed = 1,
    snapshot_date = snap
  )

  expect_s3_class(sim$Mapped_Death, "tbl_df")
  expect_named(
    sim$Mapped_Death,
    c(
      "studyid",
      "subjid",
      "death_dt",
      "death_dy",
      "death",
      "pd_date",
      "deathcls"
    )
  )
  expect_gt(nrow(sim$Mapped_Death), 0) # the seed must produce >=1 observed death
  expect_true(all(sim$Mapped_Death$death))
  expect_true(all(sim$Mapped_Death$death_dy >= 1)) # only positive time-to-death
  expect_true(all(sim$Mapped_Death$death_dt <= snap)) # censoring vs snapshot
})

test_that("pd_SimulatePrematureDeathCohort is reproducible for a fixed seed {#246}", {
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
