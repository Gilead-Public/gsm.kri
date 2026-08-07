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
  expect_equal(workflow$meta$MissingActionState, "error")
  expect_equal(workflow$meta$ActionFactors$`Open Action`, 1)
  expect_equal(workflow$meta$ActionFactors$`Closed Action`, 1)
  expect_equal(workflow$meta$ActionFactors$`Awaiting Triage`, 1)
  expect_equal(workflow$meta$ActionFactors$`No Action`, 0)
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
    ExtractionDate = as.Date("2025-03-07"),
    stringsAsFactors = FALSE
  )
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
})