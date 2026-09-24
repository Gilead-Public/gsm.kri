# Generate a deterministic ActionLog fixture aligned with gsm.core::reportingResults.
#
# Ported from gsm.core's data-raw/generate_action_log_fixture.R
# (Gilead-Public/gsm.core#183). It is vendored here because gsm.kri cannot pin
# that gsm.core branch without conflicting with the gsm.core@main remotes of its
# other gsm dependencies, and that branch's fixture only aligns with its own
# regenerated reportingResults. Rebuild whenever gsm.core's reporting data
# changes; CalculateActionRiskScore(strMissingState = "error") requires every
# flagged site KRI row to have a matching ActionLog row.
#
# Requires gsm.datasim with simulate_action_log()
# (Gilead-Public/gsm.datasim@issue-134-actionlog-simulation at time of writing).

results <- gsm.core::reportingResults
results$SnapshotDate <- as.Date(results$SnapshotDate)
metrics <- gsm.core::reportingMetrics
groups <- gsm.core::reportingGroups

if (!requireNamespace("gsm.datasim", quietly = TRUE) ||
    !exists("simulate_action_log", asNamespace("gsm.datasim"))) {
  stop(
    "Install gsm.datasim with ActionLog simulation support before regenerating this fixture.",
    call. = FALSE
  )
}

eligible <- results[
  results$GroupLevel == "Site" &
    grepl("^Analysis_kri", results$MetricID) &
    !is.na(results$Flag) &
    results$Flag != 0,
  c("StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID", "Flag"),
  drop = FALSE
]
eligible <- eligible[order(
  eligible$SnapshotDate,
  eligible$GroupID,
  eligible$MetricID
), , drop = FALSE]
row.names(eligible) <- NULL

metric_index <- match(eligible$MetricID, metrics$MetricID)
eligible$MetricLabel <- metrics$Metric[metric_index]
eligible$MetricAbbreviation <- metrics$Abbreviation[metric_index]

group_value <- function(param) {
  values <- groups[
    groups$GroupLevel == "Site" & groups$Param == param,
    c("GroupID", "Value"),
    drop = FALSE
  ]
  as.character(values$Value[match(eligible$GroupID, values$GroupID)])
}

eligible$GroupLabel <- group_value("InvestigatorLastName")
eligible$Country <- group_value("Country")

states <- c("Awaiting Triage", "No Action", "Open Action", "Closed Action")
transition_matrix <- matrix(
  0,
  nrow = length(states),
  ncol = length(states),
  dimnames = list(states, states)
)
transition_matrix["Awaiting Triage", c("Awaiting Triage", "Open Action")] <-
  c(0.25, 0.75)
transition_matrix["No Action", "No Action"] <- 1
transition_matrix["Open Action", c("Open Action", "Closed Action")] <-
  c(0.4, 0.6)
transition_matrix["Closed Action", "Closed Action"] <- 1

reportingActionLog <- gsm.datasim::simulate_action_log(
  df_results = eligible,
  state_probabilities = c(
    "Awaiting Triage" = 0.2,
    "No Action" = 0.4,
    "Open Action" = 0.2,
    "Closed Action" = 0.2
  ),
  transition_matrix = transition_matrix,
  seed = 134,
  extraction_date = max(eligible$SnapshotDate) + 14L,
  work_item_id_start = 900001L
)

group_labels <- unique(eligible[c("GroupID", "GroupLabel")])
reportingActionLog$GroupLabel <- group_labels$GroupLabel[
  match(reportingActionLog$GroupID, group_labels$GroupID)
]
reportingActionLog <- as.data.frame(reportingActionLog)

usethis::use_data(reportingActionLog, overwrite = TRUE)
