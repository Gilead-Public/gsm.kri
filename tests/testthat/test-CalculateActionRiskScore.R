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
    ExtractionDate = as.Date("2025-03-07"),
    stringsAsFactors = FALSE
  )
}

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
    "ActionFactor", "EffectiveWeight"
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