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

test_that("report_eligibility module is discoverable, wired to Report_Eligibility and declares Mapped_EXCLUSION columns (#351) (#371)", {
  wf <- GetEligibilityWorkflow()

  expect_false(is.null(wf))
  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_eligibility")
  expect_equal(wf$meta$Output, "html")

  expect_setequal(
    names(wf$spec),
    c(
      "Mapped_EXCLUSION",
      "Reporting_Results",
      "Reporting_Groups",
      "Reporting_Metrics"
    )
  )
  expect_true(isTRUE(wf$spec$Mapped_EXCLUSION[["_all"]]$required))
  expect_setequal(
    setdiff(names(wf$spec$Mapped_EXCLUSION), "_all"),
    c(
      "studyid",
      "subjid",
      "country",
      "invid",
      "Source",
      "ie_violation",
      "ietestcd_concat",
      "dvdtm",
      "eligibility_criteria",
      "pd_violation",
      "pd_important",
      "pd_nonimportant",
      "edc_query",
      "edc_pd",
      "iecat_concat"
    )
  )

  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_equal(step_fns[length(step_fns)], "gsm.kri::Report_Eligibility")

  outputs <- vapply(wf$steps, `[[`, character(1), "output")
  expect_true(all(
    c("dfResults", "dfMetrics", "dfGroups", "lListings") %in% outputs
  ))

  report_params <- wf$steps[[length(wf$steps)]]$params
  expect_setequal(
    names(report_params),
    c("dfResults", "dfMetrics", "dfGroups", "lListings", "strOutputFile")
  )
})

test_that("report_eligibility workflow runs with minimal inputs and renders the report (#351) (#371)", {
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
      ie_violation = NA,
      ietestcd_concat = NA,
      dvdtm = "2025-01-01 00:00:00",
      eligibility_criteria = "Inclusion/Exclusion description"
    )
  )

  # Report_Eligibility writes to the working directory by default.
  withr::local_dir(withr::local_tempdir())

  result <- workr::RunWorkflow(
    wf,
    lData,
    bReturnResult = FALSE,
    bKeepInputData = TRUE
  )

  # Inputs are subset to the eligibility metric and study/site groups.
  expect_setequal(unique(result$lData$dfResults$MetricID), "Analysis_qtl0001")
  expect_setequal(unique(result$lData$dfMetrics$MetricID), "Analysis_qtl0001")
  expect_setequal(unique(result$lData$dfGroups$GroupLevel), c("Study", "Site"))
  expect_false(is.unsorted(result$lData$dfResults$SnapshotDate))

  # Listings: numerator excludes "Neither"; denominator is everything.
  expect_equal(nrow(result$lData$lListings$IE_num), 1)
  expect_equal(nrow(result$lData$lListings$IE_denom), 2)

  expect_true(file.exists(normalizePath(as.character(result$lData$Report))))
})

test_that("report_eligibility workflow fills the investigator name from Site groups (#371)", {
  skip_if_not_installed("rmarkdown")
  skip_if_not_installed("knitr")
  skip_if_not_installed("workr")
  skip_if_not_installed("withr")

  wf <- GetEligibilityWorkflow()
  dfGroups <- gsm.core::reportingGroups
  bNamed <- dfGroups$GroupLevel == "Site" &
    dfGroups$Param %in% c("InvestigatorFirstName", "InvestigatorLastName") &
    !is.na(dfGroups$Value) &
    nzchar(trimws(dfGroups$Value))
  vSites <- head(unique(dfGroups$GroupID[bNamed]), 2)

  lData <- list(
    Reporting_Results = gsm.core::reportingResults_study,
    Reporting_Metrics = gsm.core::reportingMetrics_study,
    Reporting_Groups = dfGroups,
    Mapped_EXCLUSION = tibble::tibble(
      studyid = "Study01",
      invid = vSites,
      country = "US",
      subjid = c("Participant01", "Participant02"),
      Source = c("Eligibility IPD", "Neither"),
      ie_violation = NA,
      ietestcd_concat = NA,
      dvdtm = "2025-01-01 00:00:00",
      eligibility_criteria = "Inclusion/Exclusion description"
    )
  )

  withr::local_dir(withr::local_tempdir())

  result <- workr::RunWorkflow(
    wf,
    lData,
    bReturnResult = FALSE,
    bKeepInputData = TRUE
  )

  dfElig <- elig_ClassifyParticipants(
    result$lData$lListings$IE_denom,
    result$lData$dfGroups
  )
  expect_false(anyNA(dfElig$investigator))
  expect_true(file.exists(normalizePath(as.character(result$lData$Report))))
})

test_that("report_eligibility spec keeps undeclared columns when a study loads Mapped_EXCLUSION (#371)", {
  skip_if_not_installed("gsm.mapping")

  wf <- GetEligibilityWorkflow()
  df <- data.frame(
    studyid = "Study01",
    subjid = c("Participant01", "Participant02"),
    country = "US",
    invid = "Site01",
    Source = c("EDC I/E only", "Neither"),
    ie_violation = c("Y", NA),
    ietestcd_concat = c("incl1", NA),
    dvdtm = NA_character_,
    eligibility_criteria = NA_character_,
    edc_query = c("N", "Y"),
    extra_col = c("a", "b")
  )

  out <- gsm.mapping::ApplySpec(
    df,
    wf$spec$Mapped_EXCLUSION,
    "Mapped_EXCLUSION"
  )

  expect_true(all(c("edc_query", "extra_col") %in% names(out)))
  expect_false(any(c("pd_important", "iecat_concat") %in% names(out)))
  expect_type(out$ie_violation, "character")
})
