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
  states <- c(
    rep("No Action", 7),
    rep("Open Action", 2),
    "Closed Action"
  )
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

  # Independent expected calculation: the AA scenario has seven findings
  # judged No Action and three action-worthy findings (two open, one closed).
  expected_factor <- ifelse(
    action_log$State %in% c("Open Action", "Closed Action"),
    1,
    0
  )
  expected_numerator <- sum(weights$Weight * expected_factor)
  expected_denominator <- sum(tapply(
    weights$WeightMax,
    weights$MetricID,
    unique
  ))
  expected_score <- expected_numerator / expected_denominator * 100

  actual <- CalculateActionRiskScore(results, weights, action_log)
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