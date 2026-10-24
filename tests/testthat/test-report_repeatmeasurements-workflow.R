test_that("report_repeatmeasurements module is discoverable and wired to Report_RepeatMeasurements (#344)", {
  # Resolved here and passed as an absolute path: under load_all,
  # MakeWorkflowList(strPackage =) looks at the source root without inst/.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  wf <- workr::MakeWorkflowList(
    strNames = "report_repeatmeasurements",
    strPath = dir,
    bExact = TRUE
  )[["report_repeatmeasurements"]]

  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_repeatmeasurements")
  expect_equal(wf$meta$Name, "Repeat Measurements")
  expect_setequal(
    names(wf$spec),
    c("Mapped_VS", "Mapped_SUBJ", "Reporting_Results", "Reporting_Metrics")
  )
  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_equal(step_fns, c("list", "getwd", "gsm.kri::Report_RepeatMeasurements"))
  expect_equal(
    wf$steps[[3]]$params,
    list(
      dfResults = "Reporting_Results",
      dfMetrics = "Reporting_Metrics",
      lListings = "lListings",
      strOutputDir = "strOutputDir"
    )
  )
})

test_that("the report_repeatmeasurements module renders the report (#344)", {
  testthat::skip_if_not_installed("DT")
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  wf <- workr::MakeWorkflowList(
    strNames = "report_repeatmeasurements",
    strPath = dir,
    bExact = TRUE
  )
  lData <- c(
    rm_Fixture(),
    list(
      Reporting_Results = rm_FixtureResults(),
      Reporting_Metrics = rm_FixtureMetrics()
    )
  )
  strOut <- file.path(tempdir(), "Report_RepeatMeasurements.html")
  unlink(strOut)
  withr::with_dir(tempdir(), {
    quiet_render(suppressWarnings(workr::RunWorkflows(wf, lData)))
  })
  expect_true(file.exists(strOut))
  expect_match(
    paste(readLines(strOut, warn = FALSE), collapse = "\n"),
    "WT 3/8 <span class=\"ok\">= kri0020a",
    fixed = TRUE
  )
})
