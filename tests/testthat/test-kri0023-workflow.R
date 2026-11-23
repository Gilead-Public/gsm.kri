enrollment_subj <- function(counts) {
  sites <- names(counts)
  data.frame(
    subjid = unlist(lapply(sites, function(s) paste0(s, "-", seq_len(counts[[s]])))),
    invid = rep(sites, counts),
    stringsAsFactors = FALSE
  )
}

kri0023_workflow <- function() {
  workr::MakeWorkflowList(
    strNames = "kri0023",
    strPath = GetDefaultKRIPath(),
    bExact = TRUE,
    bActiveOnly = FALSE
  )[["kri0023"]]
}

kri0023_summary <- function(dfSubj, wf = kri0023_workflow()) {
  out <- workr::RunWorkflow(wf, list(Mapped_SUBJ = dfSubj))$Analysis_Summary
  out <- as.data.frame(out)
  out <- out[order(out$GroupID), ]
  rownames(out) <- NULL
  out
}

test_that("kri0023 flags the spec's 20-site example by rank (#378)", {
  TestAtLogLevel()
  counts <- stats::setNames(20:1, sprintf("S%02d", 1:20))
  out <- kri0023_summary(enrollment_subj(counts))

  # Double programming: ranks 1-2 Red, 3-4 Yellow, the rest Green.
  expect_equal(out$GroupID, names(counts))
  expect_equal(out$Numerator, as.numeric(counts))
  expect_true(all(out$Denominator == sum(counts)))
  expect_equal(out$Metric, as.numeric(counts) / sum(counts))
  expect_equal(out$Flag, c(2, 2, 1, 1, rep(0, 16)))
})

test_that("Metric is the site's share of study enrollment (#378)", {
  TestAtLogLevel()
  counts <- c(A = 40, B = 60, C = 100)
  out <- kri0023_summary(enrollment_subj(counts))
  expect_equal(out$Metric[out$GroupID == "A"], 0.20)
})

test_that("participants without a site count toward the study total only (#378)", {
  TestAtLogLevel()
  dfSubj <- enrollment_subj(c(A = 3, B = 1))
  dfSubj <- rbind(dfSubj, data.frame(subjid = "X-1", invid = NA))
  out <- kri0023_summary(dfSubj)

  expect_equal(out$GroupID, c("A", "B"))
  expect_true(all(out$Denominator == 5))
})

test_that("a study with no enrolled participants gives no rows (#378)", {
  TestAtLogLevel()
  out <- kri0023_summary(data.frame(subjid = character(), invid = character()))
  expect_equal(nrow(out), 0)
})

test_that("kri0023 weights Yellow 4 and Red 8 in the Site Risk Score (#378)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  wf <- kri0023_workflow()
  wf$meta$Active <- TRUE
  weights <- MakeWeights(gsm.reporting::MakeMetric(list(kri0023 = wf)))

  expect_equal(weights$Flag, c(0, 1, 2))
  expect_equal(weights$Weight, c(0, 4, 8))
})

test_that("kri0023 ships inactive with a Site Risk Score ID (#378)", {
  meta <- kri0023_workflow()$meta
  expect_false(meta$Active)
  expect_match(meta$ID, "^kri")
  expect_equal(meta$Threshold, "80,90")
  expect_equal(tolower(meta$AnalysisType), "identity")
})
