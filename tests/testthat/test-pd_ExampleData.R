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
