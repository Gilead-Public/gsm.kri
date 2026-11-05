make_action_score_results <- function() {
  data.frame(
    StudyID = "AA-AA-000-0000",
    SnapshotDate = as.Date("2025-02-28"),
    GroupLevel = "Site",
    GroupID = rep(c("1001", "1002"), each = 3),
    MetricID = rep(
      c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
      2
    ),
    Flag = 1,
    stringsAsFactors = FALSE
  )
}

make_action_score_weights <- function() {
  data.frame(
    MetricID = c(
      "Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"
    ),
    Flag = 1,
    Weight = c(4, 4, 8),
    WeightMax = c(4, 4, 8),
    stringsAsFactors = FALSE
  )
}

make_action_score_log <- function() {
  results <- make_action_score_results()
  data.frame(
    StudyID = results$StudyID,
    SnapshotDate = results$SnapshotDate,
    GroupLevel = results$GroupLevel,
    GroupID = results$GroupID,
    MetricID = results$MetricID,
    State = c(
      "No Action", "Open Action", "Closed Action",
      "Awaiting Triage", "No Action", "Open Action"
    ),
    ExtractionDate = results$SnapshotDate,
    stringsAsFactors = FALSE
  )
}

test_that("action recency spans signal snapshots and preserves every current KRI (#280)", {
  results <- make_action_score_results()
  history <- make_action_score_log()
  history$SnapshotDate <- as.Date("2025-01-31")
  history$RiskSignalID <- paste0("RS-", seq_len(nrow(history)))
  history$ActionID <- paste0("ACT-", seq_len(nrow(history)))
  history$ActionedDate <- as.Date("2025-02-08")
  history$ActionedDateSource <- "Monitoring decision"
  history$ActionedFlag <- 1
  history$ActionScope <- "SiteMetric"
  history$State <- "Closed Action"
  newer <- history[1, ]
  newer$SnapshotDate <- results$SnapshotDate[1]
  newer$RiskSignalID <- "RS-newer"
  newer$ActionID <- NA_character_
  newer$State <- "Awaiting Triage"
  newer$ActionedDate <- as.Date(NA)
  summary <- MakeActionSummary(
    results, rbind(history, newer), bActionHistoryComplete = TRUE
  )

  expect_equal(nrow(summary), nrow(results))
  expect_equal(summary$LastActionedDate, rep(as.Date("2025-02-08"), 6))
  expect_equal(summary$DaysSinceAction, rep(20L, 6))
  expect_true(all(summary$RecentlyAddressed))
  expect_true(all(summary$ActionRecency == "Recent"))
  expect_equal(summary$ActionRiskSignalID[1], "RS-1")
  expect_equal(summary$ActionID[1], "ACT-1")
})

make_dated_action_log <- function() {
  history <- make_action_score_log()
  history$SnapshotDate <- as.Date("2024-01-01")
  history$RiskSignalID <- paste0("RS-", seq_len(nrow(history)))
  history$ActionID <- paste0("ACT-", seq_len(nrow(history)))
  history$State <- "Closed Action"
  history$ActionedDate <- as.Date("2025-02-08")
  history$ActionedDateSource <- "Monitoring decision"
  history$ActionedFlag <- 1
  history$ActionScope <- "SiteMetric"
  history
}

test_that("disposition draft retains open and closed risk and expires no-action decisions (#280)", {
  history <- make_dated_action_log()
  history$State <- rep(c("No Action", "Open Action", "Closed Action"), 2)
  history$ActionedDate <- as.Date("2025-02-28") - c(90, 20, 20, 91, 20, 20)
  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), history,
    intActionWindowDays = 90, bActionHistoryComplete = TRUE,
    strActionPolicy = "disposition"
  )
  expect_equal(detail$ActionFactor, c(0, 1, 1, 1, 1, 1))
  expect_equal(detail$EffectiveWeight, c(0, 4, 8, 4, 4, 8))
  expect_true(all(detail$ActionPolicy == "disposition"))
  score <- CalculateActionRiskScore(
    make_action_score_results(), make_action_score_weights(), history,
    intActionWindowDays = 90, bActionHistoryComplete = TRUE,
    strActionPolicy = "disposition"
  )
  expect_equal(score$Numerator, c(12, 16))
  expect_equal(score$Denominator, c(16, 16))
  expect_equal(score$Score, c(75, 100))
  incomplete <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), history,
    intActionWindowDays = 90, strActionPolicy = "disposition"
  )
  expect_equal(incomplete$EffectiveWeight, incomplete$Weight)
  history$ActionedFlag[1] <- 0
  escalated <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), history,
    intActionWindowDays = 90, bActionHistoryComplete = TRUE,
    strActionPolicy = "disposition"
  )
  expect_equal(escalated$ActionFactor[1], 1)
  original <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), make_dated_action_log(),
    intActionWindowDays = 90, bActionHistoryComplete = TRUE
  )
  expect_true(all(original$EffectiveWeight == 0))
})

test_that("awaiting triage dates are not qualifying monitoring decisions (#280)", {
  history <- make_dated_action_log()
  history$State <- "Awaiting Triage"
  summary <- MakeActionSummary(
    make_action_score_results(), history, bActionHistoryComplete = TRUE
  )
  expect_true(all(is.na(summary$LastActionedDate)))
  expect_false(any(summary$RecentlyAddressed))
  score <- CalculateActionRiskScore(
    make_action_score_results(), make_action_score_weights(), history,
    intActionWindowDays = 90, bActionHistoryComplete = TRUE
  )
  expect_equal(score$Numerator, c(16, 16))
})

test_that("action windows include day 90 and preserve expired and unknown dates (#280)", {
  history <- make_dated_action_log()
  history$ActionedDate <- as.Date("2025-02-28") - c(90, 91, 0, 20, 20, 20)
  history$ActionedDate[4] <- as.Date(NA)
  history$ActionedDateSource[5] <- NA_character_
  history$ActionedFlag[6] <- NA_real_
  summary <- MakeActionSummary(
    make_action_score_results(), history, bActionHistoryComplete = TRUE
  )
  expect_equal(summary$ActionRecency, c("Recent", "Expired", "Recent", "Unknown", "Unknown", "Recent"))
  expect_equal(summary$RecentlyAddressed, c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(summary$LastActionedDate[2], as.Date("2024-11-29"))
  expect_equal(summary$ActionReason[6], "Reviewed severity unknown")
  shorter <- MakeActionSummary(
    make_action_score_results(), history, intActionWindowDays = 30,
    bActionHistoryComplete = TRUE
  )
  expect_equal(shorter$LastActionedDate, summary$LastActionedDate)
  expect_false(shorter$RecentlyAddressed[1])
})

test_that("recent actions do not suppress escalation, new episodes, or unknown coverage (#280)", {
  history <- make_dated_action_log()
  history$ActionedFlag[1] <- 0
  history$ActionedFlag[2] <- -1
  history$ActionScope[3] <- NA_character_
  history$ActionReopened <- c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE)
  history$ActionCriticality <- c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
  history$RiskEpisodeID <- c(rep(NA_character_, 5), "earlier-episode")
  results <- make_action_score_results()
  results$RiskEpisodeID <- c(rep(NA_character_, 5), "new-episode")
  summary <- MakeActionSummary(results, history, bActionHistoryComplete = TRUE)
  expect_false(any(summary$RecentlyAddressed))
  expect_equal(summary$ActionReason, c(
    "Changed or increased severity", "Changed or increased severity",
    "Decision coverage unknown", "Reopened finding", "Critical action",
    "Different or unknown risk episode"
  ))
  incomplete <- MakeActionSummary(make_action_score_results(), make_dated_action_log())
  expect_false(any(incomplete$RecentlyAddressed))
  expect_true(all(incomplete$ActionReason == "Incomplete action history"))
})

test_that("conflicting same-day decisions cannot suppress a current finding (#280)", {
  history <- make_dated_action_log()
  conflict <- history[1, ]
  conflict$ActionID <- "ACT-conflicting"
  conflict$ActionedFlag <- 0
  summary <- MakeActionSummary(
    make_action_score_results(), rbind(history, conflict),
    bActionHistoryComplete = TRUE
  )
  expect_equal(summary$LastActionedDate[1], as.Date("2025-02-08"))
  expect_false(summary$RecentlyAddressed[1])
  expect_equal(summary$ActionReason[1], "Conflicting latest decisions")
  expect_equal(summary$ActionCount[1], 2L)
  expect_equal(summary, MakeActionSummary(
    make_action_score_results(), rbind(conflict, history),
    bActionHistoryComplete = TRUE
  ))
})

test_that("action summary selects a complete freeze without filling missing sites (#280)", {
  history <- make_dated_action_log()
  later <- history[-1, ]
  later$ExtractionDate <- as.Date("2025-03-07")
  summary <- MakeActionSummary(
    make_action_score_results(), rbind(history, later),
    dActionExtractionDate = "2025-03-07", bActionHistoryComplete = TRUE
  )
  expect_true(is.na(summary$LastActionedDate[1]))
  expect_equal(summary$ActionRecency[1], "Never")
  expect_equal(summary$ActionExtractionDate, rep(as.Date("2025-03-07"), 6))
  frozen <- MakeActionSummary(
    make_action_score_results(), history, bActionHistoryComplete = TRUE
  )
  expect_true(all(frozen$RecentlyAddressed))
  empty <- MakeActionSummary(make_action_score_results(), history[0, ])
  expect_equal(nrow(empty), 6)
  expect_true(all(empty$ActionRecency == "Unknown"))
})

test_that("later decision events do not change an earlier action assessment (#280)", {
  history <- make_dated_action_log()
  history$ExtractionDate <- as.Date("2025-03-07")
  future <- history[1, ]
  future$ActionID <- "ACT-future"
  future$ActionedDate <- as.Date("2025-03-01")
  history$ActionReopened <- FALSE
  history$ActionCriticality <- FALSE
  future$ActionReopened <- TRUE
  future$ActionCriticality <- TRUE
  summary <- MakeActionSummary(
    make_action_score_results(), rbind(history, future),
    dActionExtractionDate = "2025-03-07", bActionHistoryComplete = TRUE
  )
  expect_true(all(summary$RecentlyAddressed))
  expect_equal(summary$ActionCount[1], 1L)
  expect_false(summary$HasReopenedAction[1])
  expect_false(summary$HasCriticalAction[1])
})

test_that("date-window scoring preserves raw denominator and zero-weight history (#280)", {
  results <- make_action_score_results()
  history <- make_dated_action_log()
  history$ActionedDate[2] <- as.Date("2024-01-01")
  weights <- make_action_score_weights()
  weights$Weight[3] <- 0
  detail <- MakeActionRiskScoreDetail(
    results, weights, history, intActionWindowDays = 90,
    bActionHistoryComplete = TRUE
  )
  expect_equal(detail$EffectiveWeight, c(0, 4, 0, 0, 0, 0))
  expect_equal(detail$LastActionedDate[3], as.Date("2025-02-08"))
  score <- CalculateActionRiskScore(
    results, weights, history, intActionWindowDays = 90,
    bActionHistoryComplete = TRUE
  )
  expect_equal(score$Numerator, c(4, 0))
  expect_equal(score$Denominator, c(16, 16))
  expect_equal(score$Metric, c(25, 0))
})

test_that("action summary validates windows, dates, and repeated identities (#280)", {
  for (invalid in list(-1, NA_real_, Inf, 0.5, c(30, 90), "90")) {
    expect_error(MakeActionSummary(
      make_action_score_results(), make_dated_action_log(), intActionWindowDays = invalid
    ), "intActionWindowDays")
  }
  history <- make_dated_action_log()
  expect_error(MakeActionSummary(
    make_action_score_results(), rbind(history, history[1, ])
  ), "unique")
  history$ActionedDate <- as.character(history$ActionedDate)
  expect_error(MakeActionSummary(make_action_score_results(), history), "ActionedDate")
})

test_that("multiple actions use the largest factor without duplicating a KRI (#280)", {
  action_log <- make_action_score_log()
  action_log$ExtractionDate <- make_action_score_results()$SnapshotDate
  action_log$RiskSignalID <- paste0("RS-", seq_len(nrow(action_log)))
  action_log$ActionID <- paste0("ACT-", seq_len(nrow(action_log)))
  additional_action <- action_log[1, ]
  additional_action$ActionID <- "ACT-additional"
  additional_action$State <- "Open Action"
  action_log <- rbind(action_log, additional_action)

  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), action_log
  )
  contribution <- detail[detail$GroupID == "1001" &
    detail$MetricID == "Analysis_kri0001", ]

  expect_equal(nrow(detail), 6)
  expect_equal(contribution$ActionFactor, 1)
  expect_equal(contribution$EffectiveWeight, 4)
  expect_equal(contribution$ActionCount, 2L)
  expect_match(contribution$ActionID, "ACT-1", fixed = TRUE)
  expect_match(contribution$ActionID, "ACT-additional", fixed = TRUE)
  expect_equal(contribution$RiskSignalID, "RS-1")
  expect_equal(
    detail,
    MakeActionRiskScoreDetail(
      make_action_score_results(), make_action_score_weights(),
      action_log[nrow(action_log):1, ]
    )
  )
  custom <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), action_log,
    lActionFactors = c(
      "No Action" = 0.2, "Open Action" = 0.6,
      "Closed Action" = 0.8, "Awaiting Triage" = 1
    )
  )
  expect_equal(custom$ActionFactor[1], 0.6)
  duplicate <- rbind(action_log, action_log[1, ])
  expect_error(
    MakeActionRiskScoreDetail(
      make_action_score_results(), make_action_score_weights(), duplicate
    ),
    "scoring key must be unique"
  )
})

test_that("later extracted triage is not known at the data snapshot (#280)", {
  action_log <- make_action_score_log()
  action_log$ExtractionDate <- as.Date("2025-03-07")
  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), action_log,
    strMissingState = "include"
  )
  expect_equal(detail$EffectiveWeight, detail$Weight)
  expect_true(all(detail$ActionSource == "Missing"))

  frozen <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(), action_log,
    dActionExtractionDate = as.Date("2025-03-07")
  )
  expect_equal(frozen$ActionExtractionDate, rep(as.Date("2025-03-07"), 6))
  expect_equal(frozen$EffectiveWeight, c(0, 4, 8, 4, 0, 8))
})

test_that("the latest complete extraction is selected before signal matching (#280)", {
  earlier <- make_action_score_log()
  earlier$ExtractionDate <- as.Date("2025-02-27")
  earlier$State <- "Open Action"
  earlier$SnapshotDate <- as.Date("2025-01-31")
  later <- make_action_score_log()
  later$ExtractionDate <- as.Date("2025-02-28")
  later <- later[-1, ]
  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(), make_action_score_weights(),
    rbind(earlier, later), strMissingState = "include"
  )
  expect_equal(detail$ActionSource[1], "Missing")
  expect_true(is.na(detail$ActionExtractionDate[1]))
  expect_equal(detail$EffectiveWeight[1], 4)
})

test_that("extraction cutoffs require one non-missing Date (#280)", {
  for (invalid in list("not-a-date", "2025-02-30", "2025-02-28-extra", as.Date(NA), as.Date(character()),
    as.Date(c("2025-02-27", "2025-02-28")))) {
    expect_error(
      MakeActionRiskScoreDetail(
        make_action_score_results(), make_action_score_weights(),
        make_action_score_log(), dActionExtractionDate = invalid
      ),
      "dActionExtractionDate"
    )
  }
})

test_that("bundled frozen core extractions score without historical leakage (#280)", {
  weights <- MakeWeights(gsm.core::reportingMetrics)
  snapshots <- sort(unique(gsm.core::reportingResults$SnapshotDate))
  for (index in seq_along(snapshots)) {
    snapshot <- snapshots[index]
    results <- gsm.core::reportingResults
    results <- results[results$SnapshotDate == snapshot &
      results$GroupLevel == "Site" & grepl("^Analysis_kri", results$MetricID) &
      results$MetricID %in% weights$MetricID, ]
    results <- results[paste(results$MetricID, results$Flag) %in%
      paste(weights$MetricID, weights$Flag), ]
    archive <- gsm.core::reportingActionLog
    detail <- MakeActionRiskScoreDetail(results, weights, archive, strMissingState = "include")
    frozen <- archive[archive$ExtractionDate <= snapshot, ]
    expect_equal(
      detail,
      MakeActionRiskScoreDetail(results, weights, frozen, strMissingState = "include")
    )
    expect_equal(nrow(detail), nrow(results))
    expect_true(any(detail$ActionCount > 1, na.rm = TRUE))
    score <- CalculateActionRiskScore(results, weights, archive, strMissingState = "include")
    raw <- CalculateRiskScore(results, weights)
    expect_equal(score$Denominator, raw$Denominator)
    expect_true(all(score$Numerator <= raw$Numerator))
  }
})

test_that("CalculateActionRiskScore filters numerator weights by action state (#280)", {
  result <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    make_action_score_log()
  )

  expect_named(result, c(
    "GroupLevel", "GroupID", "MetricID", "Numerator", "Denominator",
    "Metric", "Score", "Flag"
  ))
  expect_true(all(result$MetricID == "Analysis_srs0002"))

  site_1001 <- result[result$GroupID == "1001", ]
  expect_equal(site_1001$Numerator, 12)
  expect_equal(site_1001$Denominator, 16)
  expect_equal(site_1001$Metric, 75)

  site_1002 <- result[result$GroupID == "1002", ]
  expect_equal(site_1002$Numerator, 12)
  expect_equal(site_1002$Denominator, 16)
  expect_equal(site_1002$Metric, 75)
})

make_multi_snapshot_action_log <- function() {
  earlier <- make_action_score_log()
  earlier$SnapshotDate <- as.Date("2025-01-31")
  earlier$State <- "Open Action"
  rbind(earlier, make_action_score_log())
}

test_that("CalculateActionRiskScore defaults to the latest ActionLog snapshot (#280)", {
  result <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    make_multi_snapshot_action_log()
  )

  # The 2025-01-31 rows are all Open Action (numerator 16); the latest
  # 2025-02-28 rows give the mixed states (numerator 12).
  expect_equal(result$Numerator, c(12, 12))
})

test_that("CalculateActionRiskScore honours an explicit ActionLog snapshot (#280)", {
  result <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    make_multi_snapshot_action_log(),
    dActionSnapshotDate = as.Date("2025-01-31")
  )
  expect_equal(result$Numerator, c(16, 16))

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      make_multi_snapshot_action_log(),
      dActionSnapshotDate = as.Date("2025-01-15")
    ),
    "missing for one or more nonzero KRI weights"
  )
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      make_multi_snapshot_action_log(),
      dActionSnapshotDate = as.Date("2025-03-31")
    ),
    "must not be later than the dfResults SnapshotDate"
  )
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      make_multi_snapshot_action_log(),
      dActionSnapshotDate = "2025-01-31"
    ),
    "dActionSnapshotDate"
  )
})

test_that("an ActionLog frozen before the results snapshot is matched by site and metric (#280)", {
  action_log <- make_action_score_log()
  action_log$SnapshotDate <- as.Date("2025-01-31")

  result <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    action_log
  )

  expect_equal(result$Numerator, c(12, 12))
})

test_that("each group and metric uses its own latest ActionLog entry (#280)", {
  # 1001/kri0001 was last recorded on 2025-01-31; every other signal on
  # 2025-02-28. A single latest-date filter would drop the 1001/kri0001 entry.
  action_log <- make_action_score_log()
  history <- action_log[1, ]
  history$SnapshotDate <- as.Date("2025-01-31")
  action_log <- rbind(history, action_log[-1, ])

  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(),
    make_action_score_weights(),
    action_log
  )
  row <- detail[detail$GroupID == "1001" & detail$MetricID == "Analysis_kri0001", ]
  expect_equal(row$ActionState, "No Action")
  expect_equal(row$ActionSnapshotDate, as.Date("2025-01-31"))

  result <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    action_log
  )
  expect_equal(result$Numerator, c(12, 12))
})

test_that("MakeActionRiskScoreDetail explains every weighted contribution (#280)", {
  action_log <- make_action_score_log()
  action_log <- action_log[!(
    action_log$GroupID == "1002" & action_log$MetricID == "Analysis_kri0003"
  ), ]

  detail <- MakeActionRiskScoreDetail(
    make_action_score_results(),
    make_action_score_weights(),
    action_log,
    strMissingState = "include"
  )

  expect_named(detail, c(
    "StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID", "Flag",
    "Weight", "WeightMax", "ActionState", "ActionSnapshotDate", "ActionSource",
    "ActionFactor", "EffectiveWeight", "ActionExtractionDate",
    "RiskSignalID", "ActionID", "ActionCount"
  ))
  expect_equal(nrow(detail), nrow(make_action_score_results()))

  missing <- detail[detail$GroupID == "1002" & detail$MetricID == "Analysis_kri0003", ]
  expect_equal(missing$ActionSource, "Missing")
  expect_true(is.na(missing$ActionState))
  expect_equal(missing$EffectiveWeight, 8)

  no_action <- detail[detail$ActionState %in% "No Action", ]
  expect_true(all(no_action$EffectiveWeight == 0))

  score <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    action_log,
    strMissingState = "include"
  )
  numerators <- tapply(detail$EffectiveWeight, detail$GroupID, sum)
  expect_equal(as.numeric(numerators[score$GroupID]), score$Numerator)
})

test_that("CalculateActionRiskScore preserves the raw SRS denominator (#280)", {
  results <- make_action_score_results()
  weights <- make_action_score_weights()

  raw <- CalculateRiskScore(results, weights)
  action <- CalculateActionRiskScore(results, weights, make_action_score_log())

  expect_equal(action$Denominator, raw$Denominator)
  expect_true(all(action$Numerator <= raw$Numerator))
})

test_that("ActionLog State does not conflict with result metadata (#280)", {
  results <- make_action_score_results()
  results$State <- "Result metadata"

  result <- CalculateActionRiskScore(
    results,
    make_action_score_weights(),
    make_action_score_log()
  )

  expect_equal(result$Numerator, c(12, 12))
})

test_that("CalculateActionRiskScore applies explicit missing-state policies (#280)", {
  action_log <- make_action_score_log()
  action_log <- action_log[!(
    action_log$GroupID == "1001" &
      action_log$MetricID == "Analysis_kri0001"
  ), ]

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      action_log
    ),
    "missing for one or more nonzero KRI weights"
  )

  included <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    action_log,
    strMissingState = "include"
  )
  excluded <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    action_log,
    strMissingState = "exclude"
  )

  expect_equal(included$Numerator[included$GroupID == "1001"], 16)
  expect_equal(excluded$Numerator[excluded$GroupID == "1001"], 12)
  expect_equal(included$Denominator, excluded$Denominator)
})

test_that("typed empty ActionLog requires an explicit missing-state policy (#280)", {
  empty_action_log <- make_action_score_log()[0, , drop = FALSE]

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      empty_action_log
    ),
    "missing for one or more nonzero KRI weights"
  )
  included <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    empty_action_log,
    strMissingState = "include"
  )
  excluded <- CalculateActionRiskScore(
    make_action_score_results(),
    make_action_score_weights(),
    empty_action_log,
    strMissingState = "exclude"
  )

  expect_equal(included$Numerator, c(16, 16))
  expect_equal(excluded$Numerator, c(0, 0))
  expect_equal(included$Denominator, excluded$Denominator)
})

test_that("zero-weight KRI rows do not require ActionLog state (#280)", {
  results <- make_action_score_results()
  results$Flag[1] <- 0
  weights <- rbind(
    make_action_score_weights(),
    data.frame(
      MetricID = "Analysis_kri0001",
      Flag = 0,
      Weight = 0,
      WeightMax = 4
    )
  )
  action_log <- make_action_score_log()[-1, ]

  result <- CalculateActionRiskScore(results, weights, action_log)

  expect_equal(result$Numerator[result$GroupID == "1001"], 12)
  expect_equal(result$Denominator[result$GroupID == "1001"], 16)
})

test_that("CalculateActionRiskScore rejects unsafe ActionLog joins (#280)", {
  action_log <- make_action_score_log()
  duplicate <- rbind(action_log, action_log[1, ])
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      duplicate
    ),
    "ActionLog scoring key must be unique"
  )

  wrong_study <- action_log
  wrong_study$StudyID <- "BB-BB-000-0000"
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      wrong_study
    ),
    "same StudyID"
  )

  # Entries recorded after the results snapshot are not known at scoring time.
  future_snapshot <- action_log
  future_snapshot$SnapshotDate <- as.Date("2025-03-31")
  future_snapshot$ExtractionDate <- as.Date("2025-04-07")
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      future_snapshot
    ),
    "missing for one or more nonzero KRI weights"
  )

  unknown_state <- action_log
  unknown_state$State[1] <- "Unexpected State"
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      unknown_state
    ),
    "no configured action factor"
  )
})

test_that("CalculateActionRiskScore validates temporal and factor contracts (#280)", {
  action_log <- make_action_score_log()

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results()[, setdiff(
        names(make_action_score_results()), "StudyID"
      )],
      make_action_score_weights(),
      action_log
    ),
    "StudyID"
  )

  missing_extraction <- action_log
  missing_extraction$ExtractionDate <- NULL
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      missing_extraction
    ),
    "ExtractionDate"
  )

  missing_extraction_value <- action_log
  missing_extraction_value$ExtractionDate[1] <- as.Date(NA)
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      missing_extraction_value
    ),
    "must not be missing"
  )

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      action_log,
      lActionFactors = c("Open Action" = 1, "No Action" = 0)
    ),
    "no configured action factor"
  )

  missing_result_key <- make_action_score_results()
  missing_result_key$GroupID[1] <- NA_character_
  expect_error(
    CalculateActionRiskScore(
      missing_result_key,
      make_action_score_weights(),
      action_log
    ),
    "dfResults scoring key"
  )

  missing_action_key <- action_log
  missing_action_key$GroupID[1] <- NA_character_
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      missing_action_key
    ),
    "dfActionLog scoring key"
  )

  wrong_date_type <- action_log
  wrong_date_type$ExtractionDate <- as.character(wrong_date_type$ExtractionDate)
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      wrong_date_type
    ),
    "must use class Date"
  )

  impossible_timing <- action_log
  impossible_timing$ExtractionDate <- as.Date("2025-02-27")
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      impossible_timing
    ),
    "must not predate"
  )

  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      action_log,
      lActionFactors = c("Open Action" = 2, "No Action" = 0)
    ),
    "between 0 and 1"
  )

  multiple_snapshots <- make_action_score_results()
  multiple_snapshots$SnapshotDate[1] <- as.Date("2025-01-31")
  expect_error(
    CalculateActionRiskScore(
      multiple_snapshots,
      make_action_score_weights(),
      action_log
    ),
    "exactly one non-missing StudyID and SnapshotDate"
  )

  unnamed_factors <- c(1, 0)
  expect_error(
    CalculateActionRiskScore(
      make_action_score_results(),
      make_action_score_weights(),
      action_log,
      lActionFactors = unnamed_factors
    ),
    "uniquely named numeric mapping"
  )
})

test_that("shared risk score kernel validates helper contracts (#280)", {
  expect_error(
    JoinRiskScoreWeights(
      make_action_score_results(),
      NULL,
      "Analysis_srs0002"
    ),
    "dfWeights is NULL"
  )

  duplicate_weights <- rbind(
    make_action_score_weights(),
    make_action_score_weights()[1, ]
  )
  expect_error(
    JoinRiskScoreWeights(
      make_action_score_results(),
      duplicate_weights,
      "Analysis_srs0002"
    ),
    "MetricID.*Flag.*unique"
  )

  weighted <- JoinRiskScoreWeights(
    make_action_score_results(),
    make_action_score_weights(),
    "Analysis_srs0002"
  )
  expect_error(
    SummarizeRiskScore(weighted, "missing", "Analysis_srs0002"),
    "weight column must exist and be numeric"
  )
})