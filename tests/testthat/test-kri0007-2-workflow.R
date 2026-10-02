run_ptd <- function(id) {
  workr::RunWorkflows(ptd_workflow(id), ptd_fixture())[[paste0(
    "Analysis_",
    id
  )]]
}

read_meta <- function(id) {
  yaml::read_yaml(file.path(
    system.file(package = "gsm.kri"),
    "workflow",
    "2_metrics",
    paste0(id, ".yaml")
  ))
}

test_that("kri0007-2 scores dosed subjects by site: I1 8/10 amber, the rest below accrual (#301)", {
  res <- run_ptd("kri0007-2")$Analysis_Summary
  res <- res[order(res$GroupID), ]

  expect_equal(res$Numerator, c(8, 1, 1, 1, 1, 1))
  expect_equal(res$Denominator, rep(10, 6))
  expect_equal(res$Score[[1]], 2.24, tolerance = 0.01)
  expect_equal(res$Flag[[1]], 1)
  expect_true(all(is.na(res$Flag[-1])))
})

test_that("cou0007-2 scores dosed subjects by country (#301)", {
  res <- run_ptd("cou0007-2")$Analysis_Summary
  res <- res[order(res$GroupID), ]

  expect_equal(res$GroupID, c("DE", "US"))
  expect_equal(res$Numerator, c(3, 10))
  expect_equal(res$Denominator, c(30, 30))
  expect_equal(res$Score, c(-1, 1), tolerance = 0.01)
  expect_equal(res$Flag, c(0, 0))
})

test_that("kri0007-2 excludes non-dosed subjects from numerator and denominator (#301)", {
  input <- run_ptd("kri0007-2")$Analysis_Input

  expect_false(any(c("S61", "S62") %in% input$SubjectID))
})

test_that("kri0007-2 counts a discontinuation date with a null reason (#301)", {
  input <- run_ptd("kri0007-2")$Analysis_Input

  expect_equal(input$Numerator[input$SubjectID == "S01"], 1)
})

test_that("kri0007-2 does not count a reason without a discontinuation date (#301)", {
  input <- run_ptd("kri0007-2")$Analysis_Input

  expect_equal(input$Numerator[input$SubjectID == "S09"], 0)
  expect_equal(input$Denominator[input$SubjectID == "S09"], 1)
})

test_that("kri0007-2 counts a discontinued subject who also completed the study (#301)", {
  input <- run_ptd("kri0007-2")$Analysis_Input

  expect_equal(input$Numerator[input$SubjectID == "S03"], 1)
})

test_that("kri0007-2/cou0007-2 read only Mapped_SUBJ and keep the PTDC calibration (#301)", {
  kri <- read_meta("kri0007-2")
  cou <- read_meta("cou0007-2")

  for (wf in list(kri, cou)) {
    expect_named(wf$spec, "Mapped_SUBJ")
    expect_false("phase" %in% names(wf$spec$Mapped_SUBJ))
    expect_equal(wf$meta$Abbreviation, "PTDC")
    expect_equal(wf$meta$Metric, "Premature Treatment Discontinuation Rate")
    expect_equal(
      wf$meta$Numerator,
      "Enrolled and dosed participants who discontinue IP prematurely"
    )
    expect_equal(wf$meta$Denominator, "Enrolled & Dosed Subjects")
    expect_equal(wf$meta$Threshold, "2,3")
    expect_equal(wf$meta$Flag, "0,1,2")
    expect_equal(wf$meta$AccrualThreshold, 3)
    expect_equal(wf$meta$AccrualMetric, "Numerator")
    expect_true(wf$meta$GenerateRiskSignal)
  }
  expect_equal(kri$meta$RiskScoreWeight, "0,16,32")
  expect_null(cou$meta$RiskScoreWeight)
})

test_that("kri0007-2/cou0007-2 are active and kri0007/cou0007 inactive, so default workflow lists run only the -2 pair (#301)", {
  wf <- workr::MakeWorkflowList(
    strPath = file.path(system.file(package = "gsm.kri"), "workflow", "2_metrics")
  )

  expect_true(all(c("kri0007-2", "cou0007-2") %in% names(wf)))
  expect_false(any(c("kri0007", "cou0007") %in% names(wf)))
  for (id in c("kri0007-2", "cou0007-2")) {
    expect_true(read_meta(id)$meta$Active)
  }
  for (id in c("kri0007", "cou0007")) {
    expect_false(read_meta(id)$meta$Active)
  }
})

test_that("kri0007/cou0007 are still selectable by exact name with inactive workflows included (#301)", {
  # The default name match is a pattern and skips inactive workflows, so
  # "kri0007" alone returns kri0007-2.
  expect_named(kri_workflow("kri0007"), "kri0007-2")
  expect_named(kri_workflow("cou0007"), "cou0007-2")
  expect_named(ptd_workflow("kri0007"), "kri0007")
  expect_named(ptd_workflow("cou0007"), "cou0007")
})

test_that("kri0007/cou0007 keep the Treatment Discontinuation Rate definition (#301)", {
  for (id in c("kri0007", "cou0007")) {
    wf <- read_meta(id)
    expect_equal(wf$meta$Abbreviation, "TDSC")
    expect_equal(wf$meta$Metric, "Treatment Discontinuation Rate")
    expect_true("Mapped_SDRGCOMP" %in% names(wf$spec))
  }
})
