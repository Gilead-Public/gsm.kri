# S04 has no DQS coverage; counts straddle the placeholder 5 / 10 thresholds.
lData_kri0022 <- list(
  Mapped_BURDEN = tibble::tibble(
    studyid = "STUDY-A",
    invid = c("S01", "S02", "S03", "S04", "S05", "S06"),
    active_protocol_count = c(1L, 4L, 5L, NA, 9L, 10L)
  )
)

kri0022_workflow <- function() {
  workr::MakeWorkflowList(
    strNames = "kri0022",
    strPath = GetDefaultKRIPath(),
    bExact = TRUE,
    bActiveOnly = FALSE
  )[["kri0022"]]
}

kri0022_summary <- function(wf = kri0022_workflow()) {
  out <- workr::RunWorkflow(wf, lData_kri0022)$Analysis_Summary
  out <- as.data.frame(out)
  out <- out[order(out$GroupID), ]
  rownames(out) <- NULL
  out
}

test_that("kri0022 reports each site's active protocol count, NA without DQS coverage (#377)", {
  TestAtLogLevel()
  out <- kri0022_summary()

  expect_equal(out$GroupID, lData_kri0022$Mapped_BURDEN$invid)
  expect_true(all(out$GroupLevel == "Site"))
  expect_equal(out$Numerator, as.numeric(lData_kri0022$Mapped_BURDEN$active_protocol_count))
  expect_equal(out$Score, out$Numerator)
  expect_true(is.na(out$Score[out$GroupID == "S04"]))
  expect_true(is.na(out$Flag[out$GroupID == "S04"]))
})

test_that("kri0022 flags match an independent derivation at each threshold (#377)", {
  TestAtLogLevel()
  wf <- kri0022_workflow()
  out <- kri0022_summary(wf)

  # Double programming: Flag() bins positive scores into [a, b) intervals.
  thresholds <- as.numeric(strsplit(wf$meta$Threshold, ",")[[1]])
  count <- lData_kri0022$Mapped_BURDEN$active_protocol_count
  expected <- ifelse(
    is.na(count),
    NA,
    ifelse(count >= thresholds[2], 2, ifelse(count >= thresholds[1], 1, 0))
  )
  expect_equal(out$Flag, expected)
})

test_that("kri0022 weights Yellow 2 and Red 4 in the Site Risk Score (#377)", {
  skip_if_not_installed("gsm.reporting")
  TestAtLogLevel()
  wf <- kri0022_workflow()
  wf$meta$Active <- TRUE
  weights <- MakeWeights(gsm.reporting::MakeMetric(list(kri0022 = wf)))

  expect_equal(weights$Flag, c(0, 1, 2))
  expect_equal(weights$Weight, c(0, 2, 4))
  expect_equal(unique(weights$WeightMax), 4)

  out <- kri0022_summary(wf)
  out$MetricID <- "Analysis_kri0022"
  score <- suppressWarnings(CalculateRiskScore(out, weights))
  score <- score[order(score$GroupID), ]
  # S04 (no coverage) is dropped rather than scored 0.
  expect_equal(score$GroupID, c("S01", "S02", "S03", "S05", "S06"))
  expect_equal(score$Numerator, c(0, 0, 2, 2, 4))
})

test_that("kri0022 ships inactive with a Site Risk Score ID (#377)", {
  meta <- kri0022_workflow()$meta
  expect_false(meta$Active)
  expect_match(meta$ID, "^kri")
  expect_equal(meta$GroupLevel, "Site")
  expect_equal(meta$RiskScoreWeight, "0,2,4")
  expect_false("kri0022" %in% names(workr::MakeWorkflowList(
    strNames = "kri0022",
    strPath = GetDefaultKRIPath(),
    bExact = TRUE
  )))
})
