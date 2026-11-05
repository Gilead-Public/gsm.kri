test_that("srs0002 workflow consumes persisted KRI and ActionLog domains (#280)", {
  workflow_path <- system.file(
    "workflow",
    "2_metrics",
    "srs0002.yaml",
    package = "gsm.kri"
  )
  expect_true(nzchar(workflow_path))
  workflow <- yaml::read_yaml(workflow_path)

  expect_true(all(c("Analysis_Summary", "Reporting_ActionLog") %in%
    names(workflow$spec)))
  expect_equal(workflow$meta$ActionWindowDays, 90)
  expect_identical(workflow$meta$ActionHistoryComplete, FALSE)
  expect_true("ActionAsOfDate" %in% names(workflow$meta))
  expect_true("ActionExtractionDate" %in% names(workflow$meta))
  expect_equal(workflow$meta$Metric, "Site Review Priority Score")
})

test_that("srs0002 workflow produces canonical action-weighted rows (#280)", {
  workflow <- yaml::read_yaml(system.file(
    "workflow",
    "2_metrics",
    "srs0002.yaml",
    package = "gsm.kri"
  ))
  results <- data.frame(
    StudyID = "AA-AA-000-0000",
    SnapshotDate = as.Date("2025-02-28"),
    GroupLevel = "Site",
    GroupID = "1001",
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = 1,
    stringsAsFactors = FALSE
  )
  action_log <- data.frame(
    StudyID = results$StudyID,
    SnapshotDate = results$SnapshotDate,
    GroupLevel = results$GroupLevel,
    GroupID = results$GroupID,
    MetricID = results$MetricID,
    State = c("No Action", "Open Action"),
    ExtractionDate = results$SnapshotDate,
    stringsAsFactors = FALSE
  )
  action_log$ActionedDate <- as.Date(c("2025-02-28", NA))
  action_log$ActionedDateSource <- c("Monitoring decision", NA_character_)
  action_log$ActionedFlag <- c(1, NA_real_)
  action_log$ActionScope <- c("SiteMetric", NA_character_)
  workflow$meta$ActionHistoryComplete <- TRUE
  metrics <- data.frame(
    MetricID = results$MetricID,
    Flag = "1",
    RiskScoreWeight = c("4", "8"),
    stringsAsFactors = FALSE
  )

  testthat::local_mocked_bindings(
    MakeWorkflowList = function(...) list(),
    .package = "workr"
  )
  testthat::local_mocked_bindings(
    MakeMetric = function(...) metrics,
    .package = "gsm.reporting"
  )
  output <- workr::RunWorkflow(
    workflow,
    lData = list(
      Analysis_Summary = results,
      Reporting_ActionLog = action_log
    )
  )

  expect_identical(output$ID, "srs0002")
  expect_named(output$Analysis_Summary, c(
    "GroupLevel", "GroupID", "MetricID", "Numerator", "Denominator",
    "Metric", "Score", "Flag"
  ))
  expect_equal(output$Analysis_Summary$MetricID, "Analysis_srs0002")
  expect_equal(output$Analysis_Summary$Numerator, 8)
  expect_equal(output$Analysis_Summary$Denominator, 12)
  expect_equal(nrow(output$Analysis_ActionRiskScoreDetail), 2)
  expect_equal(output$Analysis_ActionRiskScoreDetail$RecentlyAddressed, c(TRUE, FALSE))

  workflow$meta$ActionExtractionDate <- "2025-03-07"
  action_log$ExtractionDate <- as.Date("2025-03-07")
  frozen <- workr::RunWorkflow(
    workflow,
    lData = list(Analysis_Summary = results, Reporting_ActionLog = action_log)
  )
  expect_equal(frozen$Analysis_Summary$Numerator, 8)
  missing <- workr::RunWorkflow(
    workflow,
    lData = list(Analysis_Summary = results, Reporting_ActionLog = action_log[0, ])
  )
  expect_equal(missing$Analysis_Summary$Numerator, 12)
})