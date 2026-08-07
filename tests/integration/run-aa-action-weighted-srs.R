# Controlled local integration check using the generated AA study evidence.
# Run from a checkout that also has the AA actionlog-evidence worktree.

aa_root <- Sys.getenv(
  "AA_ACTIONLOG_EVIDENCE_ROOT",
  "C:/dev/AA-AA-000-0000-worktrees/actionlog-evidence"
)
results_path <- file.path(
  aa_root,
  "data/output/actionlog-evidence/reporting-results.csv"
)
action_log_path <- file.path(
  aa_root,
  "data/output/actionlog-evidence/live-ado-action-log.csv"
)
stopifnot(file.exists(results_path), file.exists(action_log_path))

results <- utils::read.csv(
  results_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
action_log <- utils::read.csv(
  action_log_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
results$SnapshotDate <- as.Date(results$SnapshotDate)
action_log$SnapshotDate <- as.Date(action_log$SnapshotDate)
action_log$ExtractionDate <- as.Date(action_log$ExtractionDate)

snapshot_date <- as.Date("2025-02-28")
results <- results[results$SnapshotDate == snapshot_date, , drop = FALSE]
action_log <- action_log[
  action_log$SnapshotDate == snapshot_date,
  ,
  drop = FALSE
]
weights <- data.frame(
  MetricID = unique(results$MetricID),
  Flag = 1,
  Weight = 2,
  WeightMax = 2
)

raw <- gsm.kri::CalculateRiskScore(results, weights)
weighted <- gsm.kri::CalculateActionRiskScore(results, weights, action_log)
comparison <- merge(
  raw[c("GroupID", "Metric", "Numerator", "Denominator")],
  weighted[c("GroupID", "Metric", "Numerator", "Denominator")],
  by = "GroupID",
  suffixes = c("_srs0001", "_srs0002")
)
comparison <- merge(
  comparison,
  action_log[c("GroupID", "MetricID", "State")],
  by = "GroupID"
)

stopifnot(
  nrow(comparison) == 5L,
  all(comparison$Metric_srs0002[comparison$State == "No Action"] == 0),
  all(
    comparison$Metric_srs0002[
      comparison$State %in% c("Open Action", "Closed Action")
    ] == comparison$Metric_srs0001[
      comparison$State %in% c("Open Action", "Closed Action")
    ]
  ),
  identical(comparison$Denominator_srs0001, comparison$Denominator_srs0002)
)

print(comparison[order(comparison$GroupID), ], row.names = FALSE)