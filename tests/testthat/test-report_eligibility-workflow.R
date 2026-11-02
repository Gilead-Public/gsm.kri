GetEligibilityWorkflow <- function() {
  # See test-report_prematuredeath-workflow.R for why the module dir is resolved
  # here rather than through MakeWorkflowList's strPackage.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  workr::MakeWorkflowList(
    strNames = "report_eligibility",
    strPath = dir,
    bExact = TRUE
  )[["report_eligibility"]]
}

test_that("report_eligibility module is discoverable and wired to Report_Eligibility (#351)", {
  wf <- GetEligibilityWorkflow()

  expect_false(is.null(wf))
  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_eligibility")
  expect_equal(wf$meta$Output, "html")

  expect_setequal(
    names(wf$spec),
    c("Mapped_EXCLUSION", "Reporting_Results", "Reporting_Groups", "Reporting_Metrics")
  )

  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_equal(step_fns[length(step_fns)], "gsm.kri::Report_Eligibility")

  outputs <- vapply(wf$steps, `[[`, character(1), "output")
  expect_true(all(c("dfResults", "dfMetrics", "dfGroups", "lListings") %in% outputs))

  report_params <- wf$steps[[length(wf$steps)]]$params
  expect_setequal(
    names(report_params),
    c("dfResults", "dfMetrics", "dfGroups", "lListings", "strOutputFile")
  )
})

test_that("report_eligibility workflow runs with minimal inputs and renders the report (#351)", {
  skip_if_not_installed("gsm.qtl")
  skip_if_not_installed("rmarkdown")
  skip_if_not_installed("knitr")
  skip_if_not_installed("workr")
  skip_if_not_installed("withr")

  wf <- GetEligibilityWorkflow()

  lData <- list(
    Reporting_Results = gsm.core::reportingResults_study,
    Reporting_Metrics = gsm.core::reportingMetrics_study,
    Reporting_Groups = gsm.core::reportingGroups,
    Mapped_EXCLUSION = tibble::tibble(
      studyid = "Study01",
      invid = c("Site01", "Site02"),
      country = "US",
      subjid = c("Participant01", "Participant02"),
      Source = c("Eligibility IPD", "Neither"),
      ietestcd_concat = NA,
      dvdtm = "2025-01-01 00:00:00",
      eligibility_criteria = "Inclusion/Exclusion description"
    )
  )

  # Report_Eligibility writes to the working directory by default.
  withr::local_dir(withr::local_tempdir())

  result <- workr::RunWorkflow(wf, lData, bReturnResult = FALSE, bKeepInputData = TRUE)

  # Inputs are subset to the eligibility metric and study-level groups.
  expect_setequal(unique(result$lData$dfResults$MetricID), "Analysis_qtl0001")
  expect_setequal(unique(result$lData$dfMetrics$MetricID), "Analysis_qtl0001")
  expect_setequal(unique(result$lData$dfGroups$GroupLevel), "Study")
  expect_false(is.unsorted(result$lData$dfResults$SnapshotDate))

  # Listings: numerator excludes "Neither"; denominator is everything.
  expect_equal(nrow(result$lData$lListings$IE_num), 1)
  expect_equal(nrow(result$lData$lListings$IE_denom), 2)

  expect_true(file.exists(normalizePath(as.character(result$lData$Report))))
})
