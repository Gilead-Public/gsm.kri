# Site-level counts sum to the Study A example in gsm.roadmap#61 section 2.4:
# 400 screened, 300 enrolled, 100 screen failures, 18 withdrawals, 9 LTFU.
# I3 has no enrolled participants and I4 has no screened participants, so each
# metric also drops a zero-denominator site.
ctq_site_fixture <- function() {
  counts <- data.frame(
    invid = c("I1", "I2", "I3", "I4"),
    screened = c(200L, 150L, 50L, 0L),
    screen_failure = c(50L, 0L, 50L, 0L),
    enrolled = c(150L, 150L, 0L, 0L),
    withdrawal = c(9L, 9L, 0L, 0L),
    ltfu = c(6L, 3L, 0L, 0L),
    not_screened = c(0L, 0L, 0L, 2L)
  )
  rows <- lapply(seq_len(nrow(counts)), function(i) {
    x <- counts[i, ]
    idx <- seq_len(x$screened + x$not_screened)
    enrolled <- idx > x$screen_failure &
      idx <= x$screen_failure + x$enrolled
    pos <- idx - x$screen_failure
    yn <- function(cnd) ifelse(cnd, "Y", "N")
    data.frame(
      studyid = "STUDY-A",
      subjid = paste0(x$invid, "-", idx),
      invid = x$invid,
      disp_screened = yn(idx <= x$screened),
      disp_screen_failure = yn(idx <= x$screen_failure),
      disp_enrolled = yn(enrolled),
      disp_withdrawal = yn(enrolled & pos <= x$withdrawal),
      disp_ltfu = yn(
        enrolled & pos > x$withdrawal & pos <= x$withdrawal + x$ltfu
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

ctq_metric_cols <- list(
  ctq0001 = c(numerator = "disp_screen_failure", denominator = "disp_screened"),
  ctq0002 = c(numerator = "disp_withdrawal", denominator = "disp_enrolled"),
  ctq0003 = c(numerator = "disp_ltfu", denominator = "disp_enrolled")
)

# Double programming: derived directly from the flags, not via gsm.core.
ctq_expected_by_site <- function(disp, cols) {
  num <- tapply(disp[[cols[["numerator"]]]] == "Y", disp$invid, sum)
  den <- tapply(disp[[cols[["denominator"]]]] == "Y", disp$invid, sum)
  keep <- den > 0
  data.frame(
    GroupID = names(den)[keep],
    Numerator = as.numeric(num[keep]),
    Denominator = as.numeric(den[keep]),
    Metric = as.numeric(num[keep] / den[keep])
  )
}

ctq_workflows <- function() {
  workr::MakeWorkflowList(
    strNames = names(ctq_metric_cols),
    strPath = system.file("workflow", "2_metrics", package = "gsm.kri")
  )
}

ctq_run <- function() {
  workr::RunWorkflows(
    ctq_workflows(),
    list(Mapped_DISP = ctq_site_fixture())
  )
}

test_that("ctq metrics return unflagged site-level rates matching an independent derivation (#326)", {
  TestAtLogLevel()
  results <- ctq_run()
  disp <- ctq_site_fixture()

  for (id in names(ctq_metric_cols)) {
    summary <- results[[paste0("Analysis_", id)]]$Analysis_Summary
    summary <- summary[order(summary$GroupID), ]
    rownames(summary) <- NULL

    expect_equal(
      summary[c("GroupID", "Numerator", "Denominator", "Metric")],
      ctq_expected_by_site(disp, ctq_metric_cols[[id]]),
      tolerance = 1e-8
    )
    expect_true(all(summary$GroupLevel == "Site"))
    expect_true(all(is.na(summary$Score)))
    expect_true(all(is.na(summary$Flag)))
  }
})

test_that("site numerators and denominators roll up to the Study A rates (#326)", {
  TestAtLogLevel()
  results <- ctq_run()
  rollup <- vapply(names(ctq_metric_cols), function(id) {
    summary <- results[[paste0("Analysis_", id)]]$Analysis_Summary
    c(
      Numerator = sum(summary$Numerator),
      Denominator = sum(summary$Denominator)
    )
  }, numeric(2))

  expect_equal(unname(rollup["Numerator", ]), c(100, 18, 9))
  expect_equal(unname(rollup["Denominator", ]), c(400, 300, 300))
  expect_equal(
    unname(rollup["Numerator", ] / rollup["Denominator", ]),
    c(0.25, 0.06, 0.03)
  )
})

test_that("ctq metrics are active site metrics without thresholds or risk signals (#326)", {
  for (wf in ctq_workflows()) {
    expect_true(wf$meta$Active)
    expect_equal(wf$meta$GroupLevel, "Site")
    expect_false(wf$meta$GenerateRiskSignal)
    expect_null(wf$meta$Threshold)
    expect_null(wf$meta$Flag)
    expect_null(wf$meta$RiskScoreWeight)
  }
})

test_that("ctq results stay out of the site risk score (#326)", {
  TestAtLogLevel()
  srs <- yaml::read_yaml(
    system.file("workflow", "2_metrics", "srs0001.yaml", package = "gsm.kri")
  )
  filter_step <- Filter(
    function(step) step$name == "gsm.kri::FilterAnalysis",
    srs$steps
  )[[1]]

  expect_length(
    FilterAnalysis(ctq_run(), filter_step$params$strFilterIDPattern),
    0
  )
})

test_that("the site KRI report module excludes ctq metrics (#326)", {
  TestAtLogLevel()
  module <- yaml::read_yaml(
    system.file("workflow", "4_modules", "report_kri_site.yaml", package = "gsm.kri")
  )
  steps <- stats::setNames(
    module$steps,
    vapply(module$steps, `[[`, character(1), "output")
  )
  df <- data.frame(
    GroupLevel = c("Site", "Site", "Country", "Site"),
    MetricID = c(
      "Analysis_kri0001", "Analysis_ctq0002",
      "Analysis_cou0001", "Analysis_srs0001"
    )
  )

  for (output in c("Reporting_Results_Site", "Reporting_Metrics_Site")) {
    kept <- workr::RunQuery(
      strQuery = steps[[output]]$params$strQuery,
      df = df
    )
    expect_setequal(kept$MetricID, c("Analysis_kri0001", "Analysis_srs0001"))
  }
})

test_that("ctq metadata and results bind into the reporting data model (#326)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  metrics <- gsm.reporting::MakeMetric(ctq_workflows())
  expect_setequal(metrics$MetricID, paste0("Analysis_", names(ctq_metric_cols)))
  expect_true(all(metrics$GroupLevel == "Site"))

  results <- gsm.reporting::BindResults(
    lAnalysis = ctq_run(),
    strName = "Analysis_Summary",
    strStudyID = "STUDY-A"
  )
  expect_true(all(c("Numerator", "Denominator", "MetricID") %in% names(results)))
  expect_true(all(is.na(results$Score) & is.na(results$Flag)))
})