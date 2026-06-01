lData <- list(
  Mapped_SUBJ = tibble::tibble(
    subjid = c("S001", "S002", "S003", "S004"),
    invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
    country = c("USA", "USA", "CAN", "CAN")
  ),
  Mapped_Death = tibble::tibble(
    subjid = c("S001", "S002", "S004"),
    death_dy = c(20, 50, 120)
  )
)

RunOne <- function(strMetric) {
  wf <- gsm.core::MakeWorkflowList(
    strNames = strMetric,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strMetric]]
  gsm.core::RunWorkflow(wf, lData)$Analysis_Summary
}

test_that("pat0015 emits one row per enrolled subject with Flag=2 only for premature deaths {#221}", {
  out <- RunOne("pat0015")
  expect_equal(nrow(out), 4) # one row per enrolled subject
  flagged <- out$GroupID[out$Flag == 2]
  expect_setequal(flagged, c("S001", "S002")) # day-20 and day-50 deaths
  expect_false("S004" %in% flagged) # death at day 120 is outside the window
})

test_that("WindowDays override narrows the kri0015 numerator {#221}", {
  wf90 <- gsm.core::MakeWorkflowList(
    strNames = "kri0015",
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[["kri0015"]]

  wf30 <- wf90
  wf30$meta$WindowDays <- 30

  num90 <- sum(gsm.core::RunWorkflow(wf90, lData)$Analysis_Summary$Numerator)
  num30 <- sum(gsm.core::RunWorkflow(wf30, lData)$Analysis_Summary$Numerator)

  expect_equal(num90, 2) # deaths at day 20 and day 50
  expect_equal(num30, 1) # only day 20 survives a 30-day window
})
