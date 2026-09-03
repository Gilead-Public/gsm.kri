test_that("report_aegrading module is discoverable and wired to Report_AEGrading", {
  # See test-report_prematuredeath-workflow.R: MakeWorkflowList resolves strPath
  # through base system.file when strPackage is set, which under devtools::test
  # (load_all) points at the source *root* without inst/. Resolve the dir here
  # and pass it as an absolute path with strPackage = NULL.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  wf <- workr::MakeWorkflowList(
    strNames = "report_aegrading",
    strPath = dir,
    bExact = TRUE
  )[["report_aegrading"]]

  expect_false(is.null(wf))
  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_aegrading")
  expect_equal(wf$meta$MetricID, "Analysis_kri0016")
  expect_equal(wf$meta$MinAE, 20)

  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_true("gsm.kri::Report_AEGrading" %in% step_fns)

  # The report needs both mapped domains it charts from.
  expect_true(all(c("Mapped_AE", "Mapped_SUBJ") %in% names(wf$spec)))
})

test_that("Report_AEGrading validates lListings and nMinAE", {
  expect_error(
    Report_AEGrading(lListings = list(Mapped_AE = data.frame())),
    "Mapped_AE.*Mapped_SUBJ|lListings"
  )

  expect_error(
    Report_AEGrading(
      lListings = list(Mapped_AE = data.frame(), Mapped_SUBJ = data.frame()),
      nMinAE = -1
    ),
    "nMinAE"
  )
})

test_that("AEGrading_SiteDistribution summarizes grades per site", {
  dfAE <- data.frame(
    subjid = c("S1", "S1", "S1", "S2", "S2", "S3"),
    aetoxgr = c(1L, 1L, 3L, 4L, 5L, 2L)
  )
  dfSubj <- data.frame(
    subjid = c("S1", "S2", "S3"),
    invid = c("A", "A", "B")
  )

  out <- AEGrading_SiteDistribution(dfAE, dfSubj, nMinAE = 2)

  # Site B has a single AE, below nMinAE, so only site A survives.
  expect_equal(unique(out$GroupID), "A")
  # All five grades are represented, zero-filled where absent.
  expect_equal(sort(out$Grade), 1:5)
  expect_equal(sum(out$Count), 5)
  expect_equal(out$Proportion[out$Grade == 1], 0.4)
  expect_equal(out$Count[out$Grade == 2], 0)
  # Study proportions are computed before the nMinAE filter, over all 6 events.
  expect_equal(sum(out$StudyProportion), 1)
})
