test_that("Qual: action-weighted SRS matches independent AA evidence math (#280)", {
  metric_ids <- sprintf("Analysis_kri%04d", 1:10)
  results <- data.frame(
    StudyID = "AA-AA-000-0000",
    SnapshotDate = as.Date("2025-02-28"),
    GroupLevel = "Site",
    GroupID = "1001",
    MetricID = metric_ids,
    Flag = 1,
    stringsAsFactors = FALSE
  )
  weights <- data.frame(
    MetricID = metric_ids,
    Flag = 1,
    Weight = 2,
    WeightMax = 2,
    stringsAsFactors = FALSE
  )
  states <- c(rep("No Action", 7), rep("Open Action", 2), "Closed Action")
  action_log <- data.frame(
    StudyID = results$StudyID,
    SnapshotDate = results$SnapshotDate,
    GroupLevel = results$GroupLevel,
    GroupID = results$GroupID,
    MetricID = results$MetricID,
    State = states,
    ExtractionDate = as.Date("2025-03-07"),
    stringsAsFactors = FALSE
  )
  expected_factor <- ifelse(action_log$State %in% c("Open Action", "Closed Action"), 1, 0)
  expected_numerator <- sum(weights$Weight * expected_factor)
  expected_denominator <- sum(tapply(weights$WeightMax, weights$MetricID, unique))
  expected_score <- expected_numerator / expected_denominator * 100

  actual <- CalculateActionRiskScore(
    results, weights, action_log,
    dActionExtractionDate = as.Date("2025-03-07")
  )
  raw <- CalculateRiskScore(results, weights)

  expect_equal(expected_numerator, 6)
  expect_equal(expected_denominator, 20)
  expect_equal(expected_score, 30)
  expect_equal(actual$Numerator, expected_numerator)
  expect_equal(actual$Denominator, expected_denominator)
  expect_equal(actual$Metric, expected_score)
  expect_equal(actual$Score, expected_score)
  expect_equal(raw$Numerator, 20)
  expect_equal(raw$Metric, 100)
  expect_equal(actual$Denominator, raw$Denominator)
})

test_that("Qual: review priority matches independent dated decision math (#280)", {
  assessment <- as.Date("2026-11-04")
  results <- data.frame(
    StudyID = "AA-AA-000-0000", SnapshotDate = assessment,
    GroupLevel = "Site", GroupID = "1001",
    MetricID = sprintf("Analysis_kri%04d", 1:5), Flag = 2
  )
  weights <- data.frame(MetricID = results$MetricID, Flag = 2, Weight = 4, WeightMax = 4)
  actions <- results
  actions$SnapshotDate <- as.Date("2026-08-01")
  actions$ExtractionDate <- assessment
  actions$State <- c("Closed Action", "No Action", "Open Action", "Awaiting Triage", "Closed Action")
  actions$RiskSignalID <- paste0("RS-", seq_len(nrow(actions)))
  actions$ActionID <- paste0("ACT-", seq_len(nrow(actions)))
  actions$ActionedDate <- assessment - c(20, 91, 90, NA, 20)
  actions$ActionedDateSource <- "Monitoring decision"
  actions$ActionedFlag <- c(2, 2, 2, NA, 1)
  actions$ActionScope <- "SiteMetric"
  repeat_signal <- actions[1, ]
  repeat_signal$SnapshotDate <- as.Date("2026-11-01")
  repeat_signal$RiskSignalID <- "RS-repeat"
  repeat_signal$ActionID <- NA_character_
  repeat_signal$State <- "Awaiting Triage"
  repeat_signal$ActionedDate <- as.Date(NA)
  actions <- rbind(actions, repeat_signal)

  latest_dates <- as.Date(vapply(results$MetricID, function(metric) {
    eligible <- actions[actions$MetricID == metric & !is.na(actions$ActionedDate) &
      actions$State %in% c("Open Action", "Closed Action", "No Action"), ]
    if (nrow(eligible) == 0L) return(NA_real_)
    as.numeric(max(eligible$ActionedDate))
  }, numeric(1)), origin = "1970-01-01")
  ages <- as.integer(assessment - latest_dates)
  reviewed_flags <- c(2, 2, 2, NA, 1)
  excluded <- !is.na(ages) & ages >= 0 & ages <= 90 &
    !is.na(reviewed_flags) & results$Flag <= reviewed_flags
  expected_numerator <- sum(weights$Weight * !excluded)
  expected_denominator <- sum(weights$WeightMax)
  detail <- MakeActionRiskScoreDetail(
    results, weights, actions, intActionWindowDays = 90,
    bActionHistoryComplete = TRUE
  )
  actual <- CalculateActionRiskScore(
    results, weights, actions, intActionWindowDays = 90,
    bActionHistoryComplete = TRUE
  )
  expect_equal(unname(latest_dates), as.Date(c("2026-10-15", "2026-08-05", "2026-08-06", NA, "2026-10-15")))
  expect_equal(detail$LastActionedDate, unname(latest_dates))
  expect_equal(detail$RecentlyAddressed, c(TRUE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(actual$Numerator, expected_numerator)
  expect_equal(actual$Denominator, expected_denominator)
  expect_equal(actual$Metric, expected_numerator / expected_denominator * 100)
  expect_equal(actual$Metric, 60)
  expect_equal(CalculateRiskScore(results, weights)$Metric, 100)
})