grail_root <- Sys.getenv("GRAIL_PR_ROOT", "../grail")
stopifnot(dir.exists(grail_root))
pkgload::load_all(grail_root, quiet = TRUE)
pkgload::load_all(".", quiet = TRUE)

results <- data.frame(
  StudyID = "CONTRACT-STUDY",
  SnapshotDate = as.Date("2026-01-31"),
  GroupLevel = "Site",
  GroupID = c("1001", "1002", "1003"),
  MetricID = "Analysis_kri0001",
  Flag = 1,
  State = c("No Action", "Open Action", "Awaiting Triage"),
  GroupLabel = c("One", "Two", "Three"),
  stringsAsFactors = FALSE
)
weights <- data.frame(MetricID = "Analysis_kri0001", Flag = 1, Weight = 4, WeightMax = 4)

for (counts in list(c(0L, 2L, 0L), c(1L, 1L, 1L), c(0L, 0L, 0L))) {
  simulated <- gsm.datasim::simulate_action_log(
    results, extraction_date = as.Date("2026-01-31"),
    actions_per_signal = counts, include_intermediates = TRUE
  )
  grail::ValidateDomainConformance(
    simulated$all_risk_signals,
    strWorkflowPath = "workflow/3_reporting/ActionLog.yaml",
    strDomain = "Reporting_AllRiskSignals"
  )
  grail::ValidateDomainConformance(
    simulated$actions,
    strWorkflowPath = "workflow/3_reporting/ActionLog.yaml",
    strDomain = "Reporting_Actions"
  )
  actual <- grail::BuildActionLog(
    simulated$all_risk_signals, simulated$actions,
    dtExtractionDate = as.Date("2026-01-31")
  )
  testthat::expect_equal(actual, simulated$action_log)
  detail <- gsm.kri::MakeActionRiskScoreDetail(results, weights, actual)
  testthat::expect_equal(detail$EffectiveWeight, c(0, 4, 4))
  testthat::expect_equal(detail$ActionCount, counts)
}

earlier <- gsm.datasim::simulate_action_log(
  results, extraction_date = as.Date("2026-01-31"), actions_per_signal = 0L
)
results$State <- "No Action"
later <- gsm.datasim::simulate_action_log(
  results, extraction_date = as.Date("2026-02-28"), actions_per_signal = 0L
)
archive <- rbind(earlier, later)
testthat::expect_equal(
  gsm.kri::MakeActionRiskScoreDetail(results, weights, archive)$EffectiveWeight,
  c(0, 4, 4)
)
testthat::expect_equal(
  gsm.kri::MakeActionRiskScoreDetail(
    results, weights, archive, dActionExtractionDate = as.Date("2026-02-28")
  )$EffectiveWeight,
  c(0, 0, 0)
)
cat("grail ActionLog domain, report, cardinality, and frozen-extraction checks passed.\n")