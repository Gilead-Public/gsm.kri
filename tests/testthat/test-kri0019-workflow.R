kri0019_meta <- function() {
  yaml::read_yaml(file.path(
    system.file(package = "gsm.kri"),
    "workflow",
    "2_metrics",
    "kri0019.yaml"
  ))$meta
}

test_that("kri0019 counts Confirmed and Potential-outside as the site numerator (#258)", {
  TestAtLogLevel()
  # RunWorkflows keys results by "<meta$Type>_<meta$ID>", not the bare ID.
  res <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_kri0019$Analysis_Summary

  i1 <- res[res$GroupID == "I1", ]
  expect_equal(i1$Numerator, 2)
  expect_equal(i1$Denominator, 4)
})

test_that("kri0019 scores and flags sites per its YAML thresholds (#258, #312)", {
  TestAtLogLevel()
  # Derive expectations from the YAML so threshold changes don't break the test.
  meta <- kri0019_meta()
  vThreshold <- gsm.core::ParseThreshold(meta$Threshold)
  res <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_kri0019$Analysis_Summary

  bAccrued <- res[[meta$AccrualMetric]] >= meta$AccrualThreshold
  expect_true(all(is.na(res$Score[!bAccrued])))
  expect_true(all(is.na(res$Flag[!bAccrued])))

  scored <- res[bAccrued, ]
  expect_gt(nrow(scored), 0)
  expect_equal(scored$Score, scored$Numerator)
  expect_equal(
    as.numeric(scored$Flag),
    as.numeric(findInterval(scored$Score, vThreshold))
  )
  # The fixture should exercise every flag level.
  expect_setequal(scored$Flag, gsm.core::ParseThreshold(meta$Flag))
})

test_that("kri0019 flags only high counts (#258, #312)", {
  TestAtLogLevel()
  meta <- kri0019_meta()
  vThreshold <- gsm.core::ParseThreshold(meta$Threshold)

  expect_length(vThreshold, 2)
  expect_true(all(vThreshold > 0))
  expect_false(is.unsorted(vThreshold, strictly = TRUE))
  expect_equal(meta$Flag, "0,1,2")
  expect_true(meta$GenerateRiskSignal)
})

test_that("cou0019 aggregates the same numerator by country (#258)", {
  TestAtLogLevel()
  res <- workr::RunWorkflows(
    kri_workflow("cou0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_cou0019$Analysis_Summary

  us <- res[res$GroupID == "US", ]
  expect_equal(us$Numerator, 2)
  expect_equal(us$Denominator, 4)
})

test_that("cou0019 stays out of the CM Action Log (#258)", {
  TestAtLogLevel()
  meta <- yaml::read_yaml(file.path(
    system.file(package = "gsm.kri"),
    "workflow",
    "2_metrics",
    "cou0019.yaml"
  ))$meta

  # grail's KRI signal workflow admits GroupLevel IN ('Site','Country'), so
  # country is excluded by this flag alone - assert it rather than assume it.
  expect_false(meta$GenerateRiskSignal)
  expect_null(meta$RiskScoreWeight)
})
