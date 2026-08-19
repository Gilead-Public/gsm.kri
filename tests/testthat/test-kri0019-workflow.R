# Three sites, not two: gsm.core::Analyze_Poisson fits an intercept plus a free
# elasticity on log(exposure), so a two-group study is saturated and every Score
# comes back exactly 0. See the regression test at the bottom of this file.
lData_kri0019 <- list(
  Mapped_SUBJ = tibble::tibble(
    subjid = paste0("S", sprintf("%03d", 1:9)),
    invid = c(rep("INV-1", 3), rep("INV-2", 3), rep("INV-3", 3)),
    country = c(rep("USA", 3), rep("CAN", 3), rep("USA", 3)),
    firstparticipantdate = as.Date("2024-01-01"),
    timeonstudy = rep(100L, 9)
  ),
  Mapped_AE = tibble::tibble(
    # INV-1 records an early AE for every subject; INV-3 records one late AE;
    # INV-2 records none at all.
    subjid = c("S001", "S002", "S003", "S007"),
    aest_dt = as.Date(c(
      "2024-01-11",
      "2024-01-11",
      "2024-01-11",
      "2024-03-01"
    ))
  )
)

RunKRI0019 <- function(strMetric, lData = lData_kri0019) {
  wf <- workr::MakeWorkflowList(
    strNames = strMetric,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strMetric]]
  workr::RunWorkflow(wf, lData)$Analysis_Summary
}

test_that("kri0019 counts first AEs against days at risk per site", {
  out <- RunKRI0019("kri0019")

  expect_setequal(out$GroupID, c("INV-1", "INV-2", "INV-3"))
  expect_equal(unique(out$GroupLevel), "Site")

  # every INV-1 subject has a day-10 AE: 3 events over 30 days at risk
  expect_equal(out$Numerator[out$GroupID == "INV-1"], 3)
  expect_equal(out$Denominator[out$GroupID == "INV-1"], 30)
  # no INV-2 subject has an AE: 0 events, all three censored at day 100
  expect_equal(out$Numerator[out$GroupID == "INV-2"], 0)
  expect_equal(out$Denominator[out$GroupID == "INV-2"], 300)
  # INV-3 has one day-60 AE plus two subjects censored at day 100
  expect_equal(out$Numerator[out$GroupID == "INV-3"], 1)
  expect_equal(out$Denominator[out$GroupID == "INV-3"], 260)
})

test_that("kri0019 scores the AE-free site lowest", {
  out <- RunKRI0019("kri0019")

  # Negative score = fewer AEs than expected = LONG time to first AE. INV-2
  # recorded no AE at all across the largest exposure, so it must score lowest.
  expect_lt(out$Score[out$GroupID == "INV-2"], 0)
  expect_equal(out$GroupID[which.min(out$Score)], "INV-2")
  # Only the ordering is asserted, not each site's sign: gsm.core fits two
  # parameters, so with three groups the residuals are barely identified.
  expect_false(all(out$Score == 0))
})

test_that("kri0019 leaves sites below the accrual threshold unflagged", {
  lData <- lData_kri0019
  # INV-4 contributes 4 days at risk, under the 10 day-at-risk accrual gate
  lData$Mapped_SUBJ <- dplyr::bind_rows(
    lData$Mapped_SUBJ,
    tibble::tibble(
      subjid = "S010",
      invid = "INV-4",
      country = "USA",
      firstparticipantdate = as.Date("2024-01-01"),
      timeonstudy = 4L
    )
  )

  out <- RunKRI0019("kri0019", lData)

  expect_true(is.na(out$Flag[out$GroupID == "INV-4"]))
  expect_false(is.na(out$Flag[out$GroupID == "INV-2"]))
})

test_that("kri0019 ignores AEs recorded before enrollment", {
  lData <- lData_kri0019
  lData$Mapped_AE$aest_dt <- as.Date("2023-12-01") # all pre-enrollment

  out <- RunKRI0019("kri0019", lData)

  # every subject is censored at day 100, so no site records an event
  expect_equal(sum(out$Numerator), 0)
  expect_equal(out$Denominator[out$GroupID == "INV-1"], 300)
})

test_that("cou0019 rolls the same metric up to country", {
  out <- RunKRI0019("cou0019")

  expect_setequal(out$GroupID, c("USA", "CAN"))
  expect_equal(unique(out$GroupLevel), "Country")
  # USA is INV-1 + INV-3: 4 events over 290 days at risk
  expect_equal(out$Numerator[out$GroupID == "USA"], 4)
  expect_equal(out$Denominator[out$GroupID == "USA"], 290)
  expect_equal(out$Numerator[out$GroupID == "CAN"], 0)
  expect_equal(out$Denominator[out$GroupID == "CAN"], 300)
  # country metrics do not feed the site risk score
  expect_false("RiskScoreWeight" %in% names(out))
})

test_that("kri0019 and cou0019 declare a Poisson analysis type for bounds", {
  # gsm.reporting::MakeBounds dispatches on AnalysisType, so 'poisson' here is
  # what selects Analyze_Poisson_PredictBounds over the normal-approximation one
  for (strMetric in c("kri0019", "cou0019")) {
    wf <- workr::MakeWorkflowList(
      strNames = strMetric,
      strPath = GetDefaultKRIPath(),
      bExact = TRUE
    )[[strMetric]]
    expect_equal(wf$meta$AnalysisType, "poisson")
    expect_equal(wf$meta$Model, "Poisson")
  }
})

test_that("gsm.core::Analyze_Poisson is saturated with only two groups", {
  # Pins a property of the upstream model so a kri0019 fixture is never written
  # with two groups. Analyze_Poisson writes `stats::offset(LogDenominator)` in the
  # glm formula, which R reads as an ordinary covariate, so the mean is
  # exp(b0) * Denominator^b1 with b1 free rather than fixed at 1. That is
  # deliberate upstream -- Analyze_Poisson_PredictBounds reads coefficients[2] --
  # but it means two groups fit perfectly and every Score is 0. If this test ever
  # fails, the upstream model changed and the "Definition and Caveats" wording in
  # inst/report/Report_TimeToAE.Rmd needs revisiting alongside it.
  dfTransformed <- tibble::tibble(
    GroupID = c("A", "B"),
    GroupLevel = "Site",
    Numerator = c(3, 0),
    Denominator = c(30, 300),
    Metric = c(0.1, 0)
  )

  out <- gsm.core::Analyze_Poisson(dfTransformed)

  expect_equal(out$Score, c(0, 0))
})
