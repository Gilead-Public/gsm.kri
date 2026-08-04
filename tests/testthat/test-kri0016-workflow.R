# Tests for kri0016 / cou0016 (Duplicate Weight Record Rate), which applies
# Flag_Duplicates() within the standard Input_Rate/Flag_NormalApprox pipeline (#231)

Mapped_SUBJ_kri0016 <- tibble::tibble(
  subjid = sprintf("S%03d", 1:6),
  invid = rep(c("INV-1", "INV-2"), each = 3),
  country = rep(c("USA", "CAN"), each = 3)
)

# S001 and S004 each have an exact-duplicate weight across visits;
# the rest have three distinct weights.
Mapped_VS_kri0016 <- tibble::tribble(
  ~subjid, ~vs_dt, ~weight,
  "S001", as.Date("2024-01-01"), 70.0,
  "S001", as.Date("2024-02-01"), 70.0,
  "S001", as.Date("2024-03-01"), 71.5,
  "S002", as.Date("2024-01-01"), 65.0,
  "S002", as.Date("2024-02-01"), 66.2,
  "S002", as.Date("2024-03-01"), 67.0,
  "S003", as.Date("2024-01-01"), 80.0,
  "S003", as.Date("2024-02-01"), 81.1,
  "S003", as.Date("2024-03-01"), 82.0,
  "S004", as.Date("2024-01-01"), 90.0,
  "S004", as.Date("2024-02-01"), 90.0,
  "S004", as.Date("2024-03-01"), 91.0,
  "S005", as.Date("2024-01-01"), 60.0,
  "S005", as.Date("2024-02-01"), 61.0,
  "S005", as.Date("2024-03-01"), 62.0,
  "S006", as.Date("2024-01-01"), 75.0,
  "S006", as.Date("2024-02-01"), 76.0,
  "S006", as.Date("2024-03-01"), 77.0
)

RunKRI0016 <- function(strMetric, lData) {
  wf <- workr::MakeWorkflowList(
    strNames = strMetric,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strMetric]]
  workr::RunWorkflow(wf, lData)
}

test_that("kri0016 computes duplicate weight rate per site using Flag_Duplicates (#231)", {
  out <- suppressMessages(RunKRI0016(
    "kri0016",
    list(Mapped_VS = Mapped_VS_kri0016, Mapped_SUBJ = Mapped_SUBJ_kri0016)
  ))

  # subject-level: only S001 and S004 have a duplicate weight record
  expect_setequal(
    out$Analysis_Input$SubjectID[out$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_true(all(out$Analysis_Input$Denominator == 3))

  # site-level: one duplicate per site (INV-1 has S001, INV-2 has S004)
  expect_equal(nrow(out$Analysis_Summary), 2)
  expect_true(all(out$Analysis_Summary$Numerator == 1))
  expect_true(all(out$Analysis_Summary$Denominator == 9))
})

test_that("cou0016 computes duplicate weight rate per country using Flag_Duplicates (#231)", {
  out <- suppressMessages(RunKRI0016(
    "cou0016",
    list(Mapped_VS = Mapped_VS_kri0016, Mapped_SUBJ = Mapped_SUBJ_kri0016)
  ))

  expect_setequal(
    out$Analysis_Input$SubjectID[out$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_equal(nrow(out$Analysis_Summary), 2)
  expect_true(all(out$Analysis_Summary$Numerator == 1))
  expect_true(all(out$Analysis_Summary$Denominator == 9))
})

test_that("kri0016 reports zero duplicates when no weight values repeat (#231)", {
  no_dup_vs <- Mapped_VS_kri0016
  no_dup_vs$weight[no_dup_vs$subjid == "S001" & no_dup_vs$vs_dt == as.Date("2024-02-01")] <- 70.9
  no_dup_vs$weight[no_dup_vs$subjid == "S004" & no_dup_vs$vs_dt == as.Date("2024-02-01")] <- 90.9

  out <- suppressMessages(RunKRI0016(
    "kri0016",
    list(Mapped_VS = no_dup_vs, Mapped_SUBJ = Mapped_SUBJ_kri0016)
  ))

  expect_true(all(out$Analysis_Input$Numerator == 0))
  expect_true(all(out$Analysis_Summary$Numerator == 0))
})
