# Deaths on days 1, 30, 31 and 90 bracket the 30-day window; INV-3 has no
# deaths and S099 is not an enrolled subject.
lData_kri0021 <- list(
  Mapped_SUBJ = tibble::tibble(
    subjid = c("S001", "S002", "S003", "S004", "S005", "S006", "S007"),
    invid = c("INV-1", "INV-1", "INV-1", "INV-2", "INV-2", "INV-3", "INV-3")
  ),
  Mapped_Death = tibble::tibble(
    subjid = c("S001", "S002", "S004", "S005", "S099"),
    death_dy = c(1, 30, 31, 90, 10)
  )
)

kri0021_workflow <- function(strName = "kri0021") {
  workr::MakeWorkflowList(
    strNames = strName,
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )[[strName]]
}

kri0021_run <- function() {
  workr::RunWorkflows(list(kri0021 = kri0021_workflow()), lData_kri0021)
}

# Double programming: derived directly from the fixture, not via gsm.core.
kri0021_expected_by_site <- function(lData, nWindow = 30) {
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

test_that("kri0021 counts deaths on day 30 but not day 31, matching an independent derivation (#381)", {
  TestAtLogLevel()
  summary <- kri0021_run()$Analysis_kri0021$Analysis_Summary
  summary <- summary[order(summary$GroupID), ]
  rownames(summary) <- NULL

  expect_equal(
    summary[c("GroupID", "Numerator", "Denominator", "Metric")],
    kri0021_expected_by_site(lData_kri0021),
    tolerance = 1e-8
  )
  expect_equal(summary$Numerator, c(2, 0, 0)) # INV-1: days 1 and 30
  expect_true(all(summary$GroupLevel == "Site"))
  expect_true(all(is.na(summary$Score)))
  expect_true(all(is.na(summary$Flag)))
})

test_that("kri0021 site results roll up to a study rate (#381)", {
  TestAtLogLevel()
  summary <- kri0021_run()$Analysis_kri0021$Analysis_Summary
  expect_equal(sum(summary$Numerator) / sum(summary$Denominator), 2 / 7)
})

test_that("kri0021 is an active site metric without thresholds or risk signals (#381)", {
  meta <- kri0021_workflow()$meta
  expect_true(meta$Active)
  expect_equal(meta$GroupLevel, "Site")
  expect_equal(meta$Abbreviation, "DTH30")
  expect_equal(meta$WindowDays, 30)
  expect_false(meta$GenerateRiskSignal)
  expect_null(meta$Threshold)
  expect_null(meta$Flag)
  expect_null(meta$RiskScoreWeight)
})

test_that("kri0021 matches kri0015 run with a 30-day window (#381)", {
  TestAtLogLevel()
  kri0015 <- kri0021_workflow("kri0015")
  kri0015$meta$WindowDays <- 30
  cols <- c("GroupID", "Numerator", "Denominator", "Metric")
  tidy <- function(df) {
    df <- as.data.frame(df)[cols]
    df <- df[order(df$GroupID), ]
    rownames(df) <- NULL
    df
  }

  expect_equal(
    tidy(kri0021_run()$Analysis_kri0021$Analysis_Summary),
    tidy(workr::RunWorkflow(kri0015, lData_kri0021)$Analysis_Summary)
  )
})

test_that("kri0021 adds no Site Risk Score weight (#381)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  metrics <- gsm.reporting::MakeMetric(list(
    kri0015 = kri0021_workflow("kri0015"),
    kri0021 = kri0021_workflow()
  ))
  weights <- MakeWeights(metrics)

  expect_contains(weights$MetricID, "Analysis_kri0015")
  expect_false("Analysis_kri0021" %in% weights$MetricID)
})

test_that("kri0021 metadata and results bind into the reporting data model (#381)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  metrics <- gsm.reporting::MakeMetric(list(kri0021 = kri0021_workflow()))
  expect_equal(metrics$MetricID, "Analysis_kri0021")
  expect_equal(metrics$GroupLevel, "Site")

  results <- gsm.reporting::BindResults(
    lAnalysis = kri0021_run(),
    strName = "Analysis_Summary",
    strStudyID = "STUDY-A"
  )
  expect_true(all(results$MetricID == "Analysis_kri0021"))
  expect_true(all(is.na(results$Score) & is.na(results$Flag)))
})
