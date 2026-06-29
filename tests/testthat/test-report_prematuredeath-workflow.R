test_that("report_prematuredeath module is discoverable and wired to Report_PrematureDeaths {#223}", {
  # MakeWorkflowList resolves strPath through base system.file when strPackage is
  # set, which under devtools::test (load_all) points at the source *root* without
  # inst/, so it cannot find the module. Resolve the dir here instead -- the test
  # namespace is pkgload-shimmed, so system.file returns the source inst/ path --
  # then pass it as an absolute path with strPackage = NULL.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  wf <- gsm.core::MakeWorkflowList(
    strNames = "report_prematuredeath",
    strPath = dir,
    bExact = TRUE
  )[["report_prematuredeath"]]

  expect_false(is.null(wf))
  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_prematuredeath")
  expect_equal(wf$meta$WindowDays, 90)

  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_true("gsm.kri::Report_PrematureDeaths" %in% step_fns)
})
