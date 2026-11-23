# Deaths on days 1, 30, 31 and 90 bracket the 30-day window; INV-3 has no
# deaths and S099 is not an enrolled subject.
lData_ctq0004 <- list(
  Mapped_SUBJ = tibble::tibble(
    subjid = c("S001", "S002", "S003", "S004", "S005", "S006", "S007"),
    invid = c("INV-1", "INV-1", "INV-1", "INV-2", "INV-2", "INV-3", "INV-3")
  ),
  Mapped_Death = tibble::tibble(
    subjid = c("S001", "S002", "S004", "S005", "S099"),
    death_dy = c(1, 30, 31, 90, 10)
  )
)

ctq0004_workflow <- function(strName = "ctq0004") {
  workr::MakeWorkflowList(
    strNames = strName,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strName]]
}

ctq0004_run <- function() {
  workr::RunWorkflows(list(ctq0004 = ctq0004_workflow()), lData_ctq0004)
}

# Double programming: derived directly from the fixture, not via gsm.core.
ctq0004_expected_by_site <- function(lData, nWindow = 30) {
  subj <- lData$Mapped_SUBJ
  early <- lData$Mapped_Death$subjid[lData$Mapped_Death$death_dy <= nWindow]
  num <- tapply(subj$subjid %in% early, subj$invid, sum)
  den <- tapply(subj$subjid, subj$invid, length)
  data.frame(
    GroupID = names(den),
    Numerator = as.numeric(num),
    Denominator = as.numeric(den),
    Metric = as.numeric(num / den)
  )
}

test_that("ctq0004 counts deaths on day 30 but not day 31, matching an independent derivation (#381)", {
  TestAtLogLevel()
  summary <- ctq0004_run()$Analysis_ctq0004$Analysis_Summary
  summary <- summary[order(summary$GroupID), ]
  rownames(summary) <- NULL

  expect_equal(
    summary[c("GroupID", "Numerator", "Denominator", "Metric")],
    ctq0004_expected_by_site(lData_ctq0004),
    tolerance = 1e-8
  )
  expect_equal(summary$Numerator, c(2, 0, 0)) # INV-1: days 1 and 30
  expect_true(all(summary$GroupLevel == "Site"))
  expect_true(all(is.na(summary$Score)))
  expect_true(all(is.na(summary$Flag)))
})

test_that("ctq0004 site results roll up to a study rate (#381)", {
  TestAtLogLevel()
  summary <- ctq0004_run()$Analysis_ctq0004$Analysis_Summary
  expect_equal(sum(summary$Numerator) / sum(summary$Denominator), 2 / 7)
})

test_that("ctq0004 is an active site metric without thresholds or risk signals (#381)", {
  meta <- ctq0004_workflow()$meta
  expect_true(meta$Active)
  expect_equal(meta$GroupLevel, "Site")
  expect_equal(meta$Abbreviation, "DTH30")
  expect_equal(meta$WindowDays, 30)
  expect_false(meta$GenerateRiskSignal)
  expect_null(meta$Threshold)
  expect_null(meta$Flag)
  expect_null(meta$RiskScoreWeight)
})

test_that("ctq0004 matches kri0015 run with a 30-day window (#381)", {
  TestAtLogLevel()
  kri0015 <- ctq0004_workflow("kri0015")
  kri0015$meta$WindowDays <- 30
  cols <- c("GroupID", "Numerator", "Denominator", "Metric")

  expect_equal(
    ctq0004_run()$Analysis_ctq0004$Analysis_Summary[cols],
    workr::RunWorkflow(kri0015, lData_ctq0004)$Analysis_Summary[cols]
  )
})

test_that("ctq0004 stays out of the site risk score (#381)", {
  TestAtLogLevel()
  srs <- yaml::read_yaml(
    system.file("workflow", "2_metrics", "srs0001.yaml", package = "gsm.kri")
  )
  filter_step <- Filter(
    function(step) step$name == "gsm.kri::FilterAnalysis",
    srs$steps
  )[[1]]

  expect_length(
    FilterAnalysis(ctq0004_run(), filter_step$params$strFilterIDPattern),
    0
  )
})

test_that("the site KRI report module excludes ctq0004 (#381)", {
  TestAtLogLevel()
  module <- yaml::read_yaml(
    system.file("workflow", "4_modules", "report_kri_site.yaml", package = "gsm.kri")
  )
  steps <- stats::setNames(
    module$steps,
    vapply(module$steps, `[[`, character(1), "output")
  )
  df <- data.frame(
    GroupLevel = c("Site", "Site", "Country"),
    MetricID = c("Analysis_kri0015", "Analysis_ctq0004", "Analysis_cou0015")
  )

  for (output in c("Reporting_Results_Site", "Reporting_Metrics_Site")) {
    kept <- workr::RunQuery(
      strQuery = steps[[output]]$params$strQuery,
      df = df
    )
    expect_equal(kept$MetricID, "Analysis_kri0015")
  }
})

test_that("ctq0004 metadata and results bind into the reporting data model (#381)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  metrics <- gsm.reporting::MakeMetric(list(ctq0004 = ctq0004_workflow()))
  expect_equal(metrics$MetricID, "Analysis_ctq0004")
  expect_equal(metrics$GroupLevel, "Site")

  results <- gsm.reporting::BindResults(
    lAnalysis = ctq0004_run(),
    strName = "Analysis_Summary",
    strStudyID = "STUDY-A"
  )
  expect_true(all(results$MetricID == "Analysis_ctq0004"))
  expect_true(all(is.na(results$Score) & is.na(results$Flag)))
})
