action_log_key <- c("StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID")

test_that("reportingActionLog has unique canonical scoring keys (#280)", {
  expect_true(all(action_log_key %in% names(reportingActionLog)))
  expect_false(anyNA(reportingActionLog[action_log_key]))
  expect_false(anyDuplicated(reportingActionLog[action_log_key]) > 0L)
})

# Guards against gsm.core reporting data drifting away from the vendored fixture;
# regenerate with data-raw/reportingActionLog.R if this fails.
test_that("reportingActionLog aligns with flagged gsm.core site KRI results (#280)", {
  results <- gsm.core::reportingResults
  expected <- results[
    results$GroupLevel == "Site" &
      grepl("^Analysis_kri", results$MetricID) &
      !is.na(results$Flag) &
      results$Flag != 0,
    action_log_key,
    drop = FALSE
  ]
  expected$SnapshotDate <- as.Date(expected$SnapshotDate)

  make_key <- function(data) do.call(paste, c(data[action_log_key], sep = "\r"))
  expect_setequal(make_key(reportingActionLog), make_key(expected))
})

test_that("reportingActionLog contains valid longitudinal action metadata (#280)", {
  expect_s3_class(reportingActionLog$SnapshotDate, "Date")
  expect_s3_class(reportingActionLog$ExtractionDate, "Date")
  expect_true(all(reportingActionLog$ExtractionDate >= reportingActionLog$SnapshotDate))
  expect_setequal(
    unique(reportingActionLog$State),
    c("Awaiting Triage", "No Action", "Open Action", "Closed Action")
  )
  expect_false(any(reportingActionLog$RiskSignalDuplicateFlag))
  expect_true(length(unique(reportingActionLog$SnapshotDate)) > 1L)
})
