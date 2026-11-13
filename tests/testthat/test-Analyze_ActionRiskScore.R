action_analysis_fixture <- function() {
  date <- as.Date("2026-11-06")
  results <- data.frame(StudyID = "STUDY", SnapshotDate = date, GroupLevel = "Site",
    GroupID = c("1001", "1002"), MetricID = "Analysis_kri0001", Flag = 2)
  weights <- data.frame(MetricID = "Analysis_kri0001", Flag = 2, Weight = 4, WeightMax = 4)
  actions <- results
  actions$SnapshotDate <- date - 10
  actions$ExtractionDate <- date
  actions$State <- c("No Action", "Open Action")
  actions$RiskSignalID <- c("RS-1", "RS-2")
  actions$ActionID <- c("ACT-1", "ACT-2")
  list(dfResults = results, dfWeights = weights, dfActionLog = actions, bUseSnapshotDate = TRUE)
}

test_that("action analysis returns matching score and snapshot detail (#280)", {
  date <- as.Date("2026-11-06")
  results <- data.frame(StudyID = "STUDY", SnapshotDate = date, GroupLevel = "Site",
    GroupID = c("1001", "1002"), MetricID = "Analysis_kri0001", Flag = 2)
  weights <- data.frame(MetricID = "Analysis_kri0001", Flag = 2, Weight = 4, WeightMax = 4)
  actions <- results
  actions$SnapshotDate <- date - 10
  actions$ExtractionDate <- date
  actions$State <- c("No Action", "Open Action")
  actions$RiskSignalID <- c("RS-1", "RS-2")
  actions$ActionID <- c("ACT-1", "ACT-2")
  output <- Analyze_ActionRiskScore(results, weights, actions, bUseSnapshotDate = TRUE)
  expect_named(output, c("Analysis_Summary", "Analysis_ActionRiskScoreDetail"))
  expect_equal(output$Analysis_Summary$Score, c(0, 100))
  expect_equal(output$Analysis_Summary$Denominator, c(4, 4))
  expect_equal(output$Analysis_ActionRiskScoreDetail$EffectiveWeight, c(0, 4))
  expect_equal(output$Analysis_ActionRiskScoreDetail$DaysSinceAction, c(10L, 10L))
  expect_true(all(output$Analysis_ActionRiskScoreDetail$ActionDateIsProxy))
})

test_that("action analysis retains proxies when snapshot scoring is disabled (#280)", {
  fixture <- action_analysis_fixture()
  fixture$bScoreSnapshotNoAction <- FALSE
  output <- do.call(Analyze_ActionRiskScore, fixture)
  expect_equal(output$Analysis_Summary$Score, c(100, 100))
  expect_equal(output$Analysis_ActionRiskScoreDetail$DaysSinceAction, c(10L, 10L))
  expect_true(all(output$Analysis_ActionRiskScoreDetail$ActionDateIsProxy))
})

test_that("action analysis scores valid reviews without another input (#280)", {
  fixture <- action_analysis_fixture()
  fixture$dfActionLog$State <- "No Action"
  expect_identical(names(formals(Analyze_ActionRiskScore))[[4L]], "bUseSnapshotDate")
  output <- Analyze_ActionRiskScore(
    fixture$dfResults, fixture$dfWeights, fixture$dfActionLog, TRUE
  )
  expect_equal(output$Analysis_Summary$Score, c(0, 0))
  expect_equal(output$Analysis_Summary$Denominator, c(4, 4))
  expect_true(all(output$Analysis_ActionRiskScoreDetail$SnapshotDecisionExcluded))
})

test_that("action analysis ignores stale, pending and conflicting decisions (#280)", {
  fixture <- action_analysis_fixture()
  fixture$dfActionLog$SnapshotDate[[1L]] <- fixture$dfResults$SnapshotDate[[1L]] - 91
  expect_equal(do.call(Analyze_ActionRiskScore, fixture)$Analysis_Summary$Score, c(100, 100))
  fixture$dfActionLog$SnapshotDate[[1L]] <- fixture$dfResults$SnapshotDate[[1L]] - 90
  expect_equal(do.call(Analyze_ActionRiskScore, fixture)$Analysis_Summary$Score, c(0, 100))
  fixture <- action_analysis_fixture()
  newer <- fixture$dfActionLog[1, ]
  newer$SnapshotDate <- newer$SnapshotDate + 5
  newer$RiskSignalID <- "RS-3"
  newer$ActionID <- "ACT-3"
  newer$State <- "Awaiting Triage"
  fixture$dfActionLog <- rbind(fixture$dfActionLog, newer)
  output <- do.call(Analyze_ActionRiskScore, fixture)
  expect_equal(output$Analysis_Summary$Score, c(100, 100))
  expect_equal(output$Analysis_ActionRiskScoreDetail$DaysSinceAction[[1L]], 10L)
  newer$SnapshotDate <- fixture$dfActionLog$SnapshotDate[[1L]]
  newer$State <- "Closed Action"
  fixture$dfActionLog <- rbind(fixture$dfActionLog[1:2, ], newer)
  expect_equal(do.call(Analyze_ActionRiskScore, fixture)$Analysis_Summary$Score, c(100, 100))
})

test_that("action analysis uses provided freeze and preserves verified dates (#280)", {
  fixture <- action_analysis_fixture()
  fixture$dfActionLog$ExtractionDate <- fixture$dfResults$SnapshotDate + 2
  expect_equal(do.call(Analyze_ActionRiskScore, fixture)$Analysis_Summary$Score, c(0, 100))
  fixture <- action_analysis_fixture()
  fixture$dfActionLog$ActionedDate <- as.Date(c("2026-11-05", NA))
  fixture$dfActionLog$ActionedDateSource <- c("Verified", NA)
  fixture$dfActionLog$ActionedFlag <- c(2, NA)
  fixture$dfActionLog$ActionScope <- c("SiteMetric", NA)
  fixture$bActionHistoryComplete <- TRUE
  output <- do.call(Analyze_ActionRiskScore, fixture)
  expect_equal(output$Analysis_ActionRiskScoreDetail$DaysSinceAction[[1L]], 1L)
  expect_false(output$Analysis_ActionRiskScoreDetail$ActionDateIsProxy[[1L]])
  expect_equal(output$Analysis_Summary$Score, c(0, 100))
})

test_that("action analysis retains weights when no actions are available (#280)", {
  fixture <- action_analysis_fixture()
  fixture$dfActionLog <- fixture$dfActionLog[FALSE, ]
  expect_warning(output <- do.call(Analyze_ActionRiskScore, fixture), NA)
  expect_equal(output$Analysis_Summary$Score, c(100, 100))
  expect_false(any(output$Analysis_ActionRiskScoreDetail$ActionDateIsProxy))
})