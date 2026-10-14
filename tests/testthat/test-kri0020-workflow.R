vs_ids <- c(paste0("kri0020", letters[1:6]), paste0("cou0020", letters[1:6]))
vs_cols <- c(
  a = "weight", b = "pulse", c = "sysbp",
  d = "diabp", e = "resp", f = "temp"
)

run_vs <- function(strIDs) {
  workr::RunWorkflows(kri_workflow(strIDs), vs_fixture())
}

expected_group <- function(strMeasure, strLevel) {
  df <- read_fixture("vs_expected_group.csv")
  df[df$measure == strMeasure & df$GroupLevel == strLevel, ]
}

expect_matches_fixture <- function(dfSummary, dfExpected) {
  dfActual <- dfSummary[match(dfExpected$GroupID, dfSummary$GroupID), ]
  expect_equal(dfActual$GroupID, dfExpected$GroupID)
  expect_equal(dfActual$Numerator, dfExpected$Numerator)
  expect_equal(dfActual$Denominator, dfExpected$Denominator)
  expect_equal(as.numeric(dfActual$Flag), as.numeric(dfExpected$Flag))
}

test_that("all twelve repeat-measure workflows load with matching IDs (#306)", {
  TestAtLogLevel()
  expect_no_warning(wf <- kri_workflow(vs_ids))
  expect_setequal(names(wf), vs_ids)
  for (id in vs_ids) {
    meta <- wf[[id]]$meta
    expect_equal(meta$ID, id)
    expect_equal(meta$ValueCol, unname(vs_cols[substr(id, 8, 8)]))
    expect_equal(meta$Threshold, "0.2,0.3")
    expect_equal(meta$WindowLength, 3)
    expect_equal(
      meta$GroupLevel,
      if (startsWith(id, "kri")) "Site" else "Country"
    )
  }
})

test_that("site weight results match the known-answer fixture (#306)", {
  TestAtLogLevel()
  res <- run_vs("kri0020a")$Analysis_kri0020a$Analysis_Summary
  expect_matches_fixture(res, expected_group("weight", "Site"))
})

test_that("country weight results match the known-answer fixture (#306)", {
  TestAtLogLevel()
  res <- run_vs("cou0020a")$Analysis_cou0020a$Analysis_Summary
  expect_matches_fixture(res, expected_group("weight", "Country"))
})

test_that("each vital is scored independently (#306)", {
  TestAtLogLevel()
  res <- run_vs(c("kri0020b", "cou0020b"))
  expect_matches_fixture(
    res$Analysis_kri0020b$Analysis_Summary,
    expected_group("pulse", "Site")
  )
  expect_matches_fixture(
    res$Analysis_cou0020b$Analysis_Summary,
    expected_group("pulse", "Country")
  )
})

test_that("vitals without repeats have zero numerators (#306)", {
  TestAtLogLevel()
  ids <- c("kri0020c", "kri0020d", "kri0020e", "kri0020f")
  res <- run_vs(ids)
  for (id in ids) {
    dfSummary <- res[[paste0("Analysis_", id)]]$Analysis_Summary
    expect_equal(sum(dfSummary$Numerator), 0, label = id)
  }
})

test_that("country variants stay out of the CM Action Log (#306)", {
  TestAtLogLevel()
  wf <- kri_workflow(vs_ids)
  for (id in vs_ids) {
    expect_equal(wf[[id]]$meta$GenerateRiskSignal, startsWith(id, "kri"))
  }
})

test_that("workflow results do not depend on Mapped_VS row order (#307)", {
  TestAtLogLevel()
  lData <- vs_fixture()
  lShuffled <- lData
  lShuffled$Mapped_VS <- lData$Mapped_VS[rev(seq_len(nrow(lData$Mapped_VS))), ]
  ids <- c("kri0020a", "cou0020a")
  res <- workr::RunWorkflows(kri_workflow(ids), lData)
  resShuffled <- workr::RunWorkflows(kri_workflow(ids), lShuffled)
  for (id in ids) {
    strName <- paste0("Analysis_", id)
    expect_equal(
      resShuffled[[strName]]$Analysis_Summary,
      res[[strName]]$Analysis_Summary,
      label = id
    )
  }
})

test_that("MakeWorkflowList regex path matches all suffixed variants (#306)", {
  TestAtLogLevel()
  strPath <- file.path(system.file(package = "gsm.kri"), "workflow", "2_metrics")
  expect_no_warning(
    wf <- workr::MakeWorkflowList(strNames = "kri0020", strPath = strPath)
  )
  expect_setequal(names(wf), paste0("kri0020", letters[1:6]))
  # Exact-name selection loads only the requested variant.
  wfOne <- workr::MakeWorkflowList(strNames = "kri0020b", strPath = strPath)
  expect_equal(names(wfOne), "kri0020b")
})

test_that("MakeMetric builds Analysis_ IDs for suffixed variants (#306)", {
  TestAtLogLevel()
  dfMetrics <- gsm.reporting::MakeMetric(kri_workflow(vs_ids))
  expect_setequal(dfMetrics$MetricID, paste0("Analysis_", vs_ids))
  expect_equal(anyDuplicated(dfMetrics$MetricID), 0)
})

test_that("suffixed IDs flow through reporting outputs (#306)", {
  TestAtLogLevel()
  ids <- c("kri0020a", "cou0020a")
  res <- run_vs(ids)
  expect_setequal(names(res), paste0("Analysis_", ids))
  dfResults <- gsm.reporting::BindResults(
    lAnalysis = res,
    strName = "Analysis_Summary",
    dSnapshotDate = as.Date("2024-02-01"),
    strStudyID = "FIXTURE"
  )
  expect_setequal(unique(dfResults$MetricID), paste0("Analysis_", ids))
})
