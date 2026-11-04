test_that("report_ipmonitoring module is discoverable and wired to Report_IPMonitoring (#320, #337)", {
  # Resolved here and passed as an absolute path: under load_all,
  # MakeWorkflowList(strPackage =) looks at the source root without inst/.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  wf <- workr::MakeWorkflowList(
    strNames = "report_ipmonitoring",
    strPath = dir,
    bExact = TRUE
  )[["report_ipmonitoring"]]

  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_ipmonitoring")
  expect_equal(
    wf$meta$Name,
    "IP monitoring: IP Non-Starter & Premature Treatment Discontinuation"
  )
  expect_setequal(
    names(wf$spec),
    c("Mapped_IPNS", "Mapped_SUBJ", "Mapped_STUDCOMP", "Reporting_Results")
  )
  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_equal(step_fns, c("list", "getwd", "gsm.kri::Report_IPMonitoring"))
  expect_equal(
    wf$steps[[3]]$params,
    list(
      dfResults = "Reporting_Results",
      lListings = "lListings",
      strOutputDir = "strOutputDir"
    )
  )
})

test_that("the report_ipmonitoring module renders the report (#320, #337)", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  wf <- workr::MakeWorkflowList(
    strNames = "report_ipmonitoring",
    strPath = dir,
    bExact = TRUE
  )
  f <- ipm_Fixture()
  lData <- c(
    f,
    list(Reporting_Results = data.frame(SnapshotDate = ipm_FixtureSnapshotDate))
  )
  withr::with_dir(tempdir(), {
    out <- quiet_render(suppressWarnings(workr::RunWorkflows(wf, lData)))
  })
  expect_true(file.exists(file.path(tempdir(), "Report_IPMonitoring.html")))
})
