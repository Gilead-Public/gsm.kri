# Tests for kri0017/cou0017 (Duplicate Systolic BP Record Rate) and
# kri0018/cou0018 (Duplicate Diastolic BP Record Rate), copy-identical to
# kri0016/cou0016 except for ValueCol (#232)

Mapped_SUBJ_dupbp <- tibble::tibble(
  subjid = sprintf("S%03d", 1:6),
  invid = rep(c("INV-1", "INV-2"), each = 3),
  country = rep(c("USA", "CAN"), each = 3)
)

# S001 and S004 each have an exact-duplicate sysbp/diabp value across visits;
# the rest have three distinct values.
Mapped_VS_dupbp <- tibble::tribble(
  ~subjid, ~vs_dt, ~sysbp, ~diabp,
  "S001", as.Date("2024-01-01"), 120, 80,
  "S001", as.Date("2024-02-01"), 120, 80,
  "S001", as.Date("2024-03-01"), 122, 81,
  "S002", as.Date("2024-01-01"), 118, 76,
  "S002", as.Date("2024-02-01"), 119, 77,
  "S002", as.Date("2024-03-01"), 121, 78,
  "S003", as.Date("2024-01-01"), 130, 85,
  "S003", as.Date("2024-02-01"), 131, 86,
  "S003", as.Date("2024-03-01"), 132, 87,
  "S004", as.Date("2024-01-01"), 140, 90,
  "S004", as.Date("2024-02-01"), 140, 90,
  "S004", as.Date("2024-03-01"), 141, 91,
  "S005", as.Date("2024-01-01"), 110, 70,
  "S005", as.Date("2024-02-01"), 111, 71,
  "S005", as.Date("2024-03-01"), 112, 72,
  "S006", as.Date("2024-01-01"), 125, 82,
  "S006", as.Date("2024-02-01"), 126, 83,
  "S006", as.Date("2024-03-01"), 127, 84
)

RunDupBP <- function(strMetric, lData) {
  wf <- workr::MakeWorkflowList(
    strNames = strMetric,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strMetric]]
  workr::RunWorkflow(wf, lData)
}

test_that("kri0017/cou0017 compute duplicate systolic BP rate via Flag_Duplicates (#232)", {
  out_kri <- suppressMessages(RunDupBP(
    "kri0017",
    list(Mapped_VS = Mapped_VS_dupbp, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))
  out_cou <- suppressMessages(RunDupBP(
    "cou0017",
    list(Mapped_VS = Mapped_VS_dupbp, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))

  expect_setequal(
    out_kri$Analysis_Input$SubjectID[out_kri$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_true(all(out_kri$Analysis_Input$Denominator == 3))
  expect_equal(nrow(out_kri$Analysis_Summary), 2)
  expect_true(all(out_kri$Analysis_Summary$Numerator == 1))

  expect_setequal(
    out_cou$Analysis_Input$SubjectID[out_cou$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_equal(nrow(out_cou$Analysis_Summary), 2)
})

test_that("kri0018/cou0018 compute duplicate diastolic BP rate via Flag_Duplicates (#232)", {
  out_kri <- suppressMessages(RunDupBP(
    "kri0018",
    list(Mapped_VS = Mapped_VS_dupbp, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))
  out_cou <- suppressMessages(RunDupBP(
    "cou0018",
    list(Mapped_VS = Mapped_VS_dupbp, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))

  expect_setequal(
    out_kri$Analysis_Input$SubjectID[out_kri$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_true(all(out_kri$Analysis_Input$Denominator == 3))
  expect_equal(nrow(out_kri$Analysis_Summary), 2)
  expect_true(all(out_kri$Analysis_Summary$Numerator == 1))

  expect_setequal(
    out_cou$Analysis_Input$SubjectID[out_cou$Analysis_Input$Numerator == 1],
    c("S001", "S004")
  )
  expect_equal(nrow(out_cou$Analysis_Summary), 2)
})

test_that("kri0017/kri0018 report zero duplicates when values do not repeat (#232)", {
  no_dup_vs <- Mapped_VS_dupbp
  no_dup_vs$sysbp[no_dup_vs$subjid == "S001" & no_dup_vs$vs_dt == as.Date("2024-02-01")] <- 999
  no_dup_vs$diabp[no_dup_vs$subjid == "S004" & no_dup_vs$vs_dt == as.Date("2024-02-01")] <- 999

  out_sbp <- suppressMessages(RunDupBP(
    "kri0017",
    list(Mapped_VS = no_dup_vs, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))
  out_dbp <- suppressMessages(RunDupBP(
    "kri0018",
    list(Mapped_VS = no_dup_vs, Mapped_SUBJ = Mapped_SUBJ_dupbp)
  ))

  # S001's sysbp duplicate was broken, but S004's remains for sysbp
  expect_equal(out_sbp$Analysis_Input$Numerator[out_sbp$Analysis_Input$SubjectID == "S001"], 0)
  expect_equal(out_sbp$Analysis_Input$Numerator[out_sbp$Analysis_Input$SubjectID == "S004"], 1)

  # S004's diabp duplicate was broken, but S001's remains for diabp
  expect_equal(out_dbp$Analysis_Input$Numerator[out_dbp$Analysis_Input$SubjectID == "S004"], 0)
  expect_equal(out_dbp$Analysis_Input$Numerator[out_dbp$Analysis_Input$SubjectID == "S001"], 1)
})
