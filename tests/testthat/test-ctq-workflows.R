ctq_study_fixture <- function(
  studyid,
  n_screened,
  n_screen_failure,
  n_enrolled,
  n_withdrawal,
  n_ltfu,
  n_not_screened = 5L
) {
  n_subjects <- n_screened + n_not_screened
  enrolled_ids <- seq.int(n_screen_failure + 1L, n_screen_failure + n_enrolled)
  withdrawal_ids <- seq.int(n_screen_failure + 1L, n_screen_failure + n_withdrawal)
  ltfu_ids <- seq.int(
    n_screen_failure + n_withdrawal + 1L,
    n_screen_failure + n_withdrawal + n_ltfu
  )

  disp_enrolled <- rep("N", n_subjects)
  disp_enrolled[enrolled_ids] <- "Y"

  disp_screen_failure <- rep("N", n_subjects)
  disp_screen_failure[seq_len(n_screen_failure)] <- "Y"

  disp_withdrawal <- rep("N", n_subjects)
  disp_withdrawal[withdrawal_ids] <- "Y"

  disp_ltfu <- rep("N", n_subjects)
  disp_ltfu[ltfu_ids] <- "Y"

  data.frame(
    studyid = studyid,
    subjid = paste0(studyid, "-", seq_len(n_subjects)),
    disp_screened = ifelse(seq_len(n_subjects) <= n_screened, "Y", "N"),
    disp_enrolled = disp_enrolled,
    disp_screen_failure = disp_screen_failure,
    disp_withdrawal = disp_withdrawal,
    disp_ltfu = disp_ltfu,
    stringsAsFactors = FALSE
  )
}

test_that("study disposition metrics match independent rates and reporting schemas", {
  TestAtLogLevel()

  mapped_disp <- dplyr::bind_rows(
    ctq_study_fixture(
      "STUDY-A",
      n_screened = 400L,
      n_screen_failure = 100L,
      n_enrolled = 300L,
      n_withdrawal = 18L,
      n_ltfu = 9L
    ),
    ctq_study_fixture(
      "STUDY-B",
      n_screened = 100L,
      n_screen_failure = 20L,
      n_enrolled = 80L,
      n_withdrawal = 8L,
      n_ltfu = 4L
    )
  )
  metric_ids <- c("ctq0001", "ctq0002", "ctq0003")
  workflows <- workr::MakeWorkflowList(
    strNames = metric_ids,
    strPath = file.path(
      system.file(package = "gsm.kri"),
      "workflow",
      "2_metrics"
    )
  )
  results <- workr::RunWorkflows(
    workflows,
    list(Mapped_DISP = mapped_disp)
  )

  expected <- list(
    ctq0001 = data.frame(
      GroupID = c("STUDY-A", "STUDY-B"),
      Numerator = c(100, 20),
      Denominator = c(400, 100),
      Metric = c(0.25, 0.20)
    ),
    ctq0002 = data.frame(
      GroupID = c("STUDY-A", "STUDY-B"),
      Numerator = c(18, 8),
      Denominator = c(300, 80),
      Metric = c(0.06, 0.10)
    ),
    ctq0003 = data.frame(
      GroupID = c("STUDY-A", "STUDY-B"),
      Numerator = c(9, 4),
      Denominator = c(300, 80),
      Metric = c(0.03, 0.05)
    )
  )

  for (id in metric_ids) {
    summary <- results[[paste0("Analysis_", id)]]$Analysis_Summary
    summary <- summary[order(summary$GroupID), ]
    rownames(summary) <- NULL

    expect_equal(
      summary[c("GroupID", "Numerator", "Denominator", "Metric")],
      expected[[id]],
      tolerance = 1e-8
    )
    expect_equal(summary$GroupLevel, c("Study", "Study"))
    expect_true(all(is.na(summary$Score)))
    expect_true(all(is.na(summary$Flag)))
  }

  study_a_rates <- vapply(metric_ids, function(id) {
    results[[paste0("Analysis_", id)]]$Analysis_Summary$Metric[
      results[[paste0("Analysis_", id)]]$Analysis_Summary$GroupID == "STUDY-A"
    ]
  }, numeric(1))
  expect_equal(unname(study_a_rates), c(0.25, 0.06, 0.03))

  expect_true(all(vapply(workflows, function(wf) {
    identical(wf$meta$GenerateRiskSignal, FALSE) &&
      is.null(wf$meta$Threshold) &&
      is.null(wf$meta$Flag) &&
      is.null(wf$meta$RiskScoreWeight)
  }, logical(1))))

  if (requireNamespace("gsm.reporting", quietly = TRUE)) {
    metrics <- gsm.reporting::MakeMetric(workflows)
    expect_setequal(metrics$MetricID, paste0("Analysis_", metric_ids))
    expect_false(any(c("Threshold", "Flag", "RiskScoreWeight") %in% names(metrics)))

    reporting_results <- gsm.reporting::BindResults(
      lAnalysis = results,
      strName = "Analysis_Summary",
      strStudyID = "REPORTING-STUDY"
    )
    expect_true(
      all(c("Score", "Flag", "MetricID", "SnapshotDate", "StudyID") %in%
        names(reporting_results))
    )
    expect_true(all(is.na(reporting_results$Score)))
    expect_true(all(is.na(reporting_results$Flag)))
  }
})
