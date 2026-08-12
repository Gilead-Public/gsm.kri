# IP Non-Starter metrics kri0016 / cou0016 / pat0016 (gsm.kri#258).
# Inline Mapped_NonStarter fixture: confirmed non-starters are S001, S003
# (site INV-1 / USA) and S006 (site INV-2 / CAN).

lData_ns0016 <- list(
  Mapped_SUBJ = tibble::tibble(
    subjid = sprintf("S%03d", 1:6),
    invid = c("INV-1", "INV-1", "INV-1", "INV-2", "INV-2", "INV-2"),
    country = c("USA", "USA", "USA", "CAN", "CAN", "CAN")
  ),
  Mapped_NonStarter = tibble::tibble(
    subjid = sprintf("S%03d", 1:6),
    invid = c("INV-1", "INV-1", "INV-1", "INV-2", "INV-2", "INV-2"),
    country = c("USA", "USA", "USA", "CAN", "CAN", "CAN"),
    dosed = c(FALSE, TRUE, FALSE, TRUE, TRUE, FALSE),
    nonstarter_status = c(
      "Confirmed",
      "Started",
      "Confirmed",
      "Started",
      "Potential-within",
      "Confirmed"
    ),
    confirmed_nonstarter = c(1L, 0L, 1L, 0L, 0L, 1L)
  )
)

RunOne <- function(strMetric) {
  wf <- gsm.core::MakeWorkflowList(
    strNames = strMetric,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strMetric]]
  gsm.core::RunWorkflow(wf, lData_ns0016)$Analysis_Summary
}

test_that("kri0016 counts confirmed non-starters per site {#258}", {
  out <- RunOne("kri0016")
  num <- setNames(out$Numerator, out$GroupID)
  den <- setNames(out$Denominator, out$GroupID)
  expect_equal(num[["INV-1"]], 2)
  expect_equal(num[["INV-2"]], 1)
  expect_equal(den[["INV-1"]], 3)
  expect_equal(den[["INV-2"]], 3)
})

test_that("cou0016 counts confirmed non-starters per country {#258}", {
  out <- RunOne("cou0016")
  num <- setNames(out$Numerator, out$GroupID)
  den <- setNames(out$Denominator, out$GroupID)
  expect_equal(num[["USA"]], 2)
  expect_equal(num[["CAN"]], 1)
  expect_equal(den[["USA"]], 3)
  expect_equal(den[["CAN"]], 3)
})

test_that("kri0016/cou0016 score groups at realistic enrollment {#258}", {
  # The denominator counts enrolled subjects, so the accrual threshold must be
  # on that scale: cloning kri0001's 30 (a Days-on-Study metric) left every
  # group below accrual and therefore unscored.
  for (strMetric in c("kri0016", "cou0016")) {
    out <- RunOne(strMetric)
    expect_false(any(is.na(out$Score)), label = strMetric)
    expect_false(any(is.na(out$Flag)), label = strMetric)
  }
})

test_that("pat0016 reports confirmed non-starter status per enrolled subject {#258}", {
  out <- RunOne("pat0016")
  expect_equal(nrow(out), 6) # one row per enrolled subject
  num <- setNames(out$Numerator, out$GroupID)
  expect_equal(unname(num[c("S001", "S003", "S006")]), c(1, 1, 1))
  expect_equal(unname(num[c("S002", "S004", "S005")]), c(0, 0, 0))
})
