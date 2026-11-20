dfResults <- data.frame(
  StudyID = "S1",
  GroupLevel = "Site",
  GroupID = "G1",
  MetricID = "M1",
  Flag = 1,
  Flag_Previous = 0,
  Flag_Change = 1,
  SnapshotDate = as.Date("2024-01-01"),
  Score = 1.2,
  Score_Previous = 0.9,
  Score_Change = 0.3,
  Numerator = 4,
  Denominator = 5,
  Metric = 0.8,
  Numerator_Previous = 3,
  Denominator_Previous = 5,
  Metric_Previous = 0.6
)

test_that("returns NULL if required columns are missing (#75)", {
  # Test data from gsm.datasim now includes delta columns; drop them explicitly.
  df <- gsm.core::reportingResults
  df <- df[, !grepl("_(Previous|Change)$", names(df))]
  output <- capture.output(result <- Report_FlagChange(df))
  expect_null(result)
  expect_true(any(grepl("Missing delta columns", output)))
})

test_that("GroupLabel and MetricLabel default to IDs when missing (#75)", {
  output <- capture.output(Report_FlagChange(dfResults))
  expect_true(any(grepl("G1", output))) # GroupLabel fallback
  expect_true(any(grepl("M1", output))) # MetricLabel fallback
})

test_that("No output if only change is NA -> 0 (green) (#75)", {
  dfResults <- data.frame(
    StudyID = "S1",
    GroupLevel = "Site",
    GroupID = "G1",
    MetricID = "M1",
    Flag = 0,
    Flag_Previous = NA,
    Flag_Change = 1,
    SnapshotDate = as.Date("2024-01-01"),
    Score = 1.2,
    Score_Previous = NA,
    Score_Change = NA,
    Numerator = 4,
    Denominator = 5,
    Metric = 0.8,
    Numerator_Previous = NA,
    Denominator_Previous = NA,
    Metric_Previous = NA,
    GroupLabel = "Group A",
    MetricLabel = "Metric A"
  )

  output <- capture.output(Report_FlagChange(dfResults))
  expect_true(any(grepl("Found 0 Risk Signals", output)))
})

test_that("HTML output is generated for valid changed flags (#75)", {
  output <- capture.output(Report_FlagChange(dfResults))
  expect_true(any(grepl("Flags Changes", output)))
  expect_true(any(grepl("G1", output)))
  expect_true(any(grepl("amber", output)))
})
