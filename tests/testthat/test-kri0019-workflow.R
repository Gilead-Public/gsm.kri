test_that("kri0019 counts Confirmed and Potential-outside as the site numerator (#258)", {
  # RunWorkflows keys results by "<meta$Type>_<meta$ID>", not the bare ID.
  res <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_kri0019$Analysis_Summary

  i1 <- res[res$GroupID == "I1", ]
  expect_equal(i1$Numerator, 2)
  expect_equal(i1$Denominator, 4)
})

test_that("kri0019 flags the site count of non-starters: 1 amber, 2+ red (#312)", {
  res <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_kri0019$Analysis_Summary

  i1 <- res[res$GroupID == "I1", ]
  i2 <- res[res$GroupID == "I2", ]
  expect_equal(c(i1$Score, i1$Flag), c(2, 2))
  expect_equal(c(i2$Score, i2$Flag), c(1, 1))
})

test_that("kri0019 uses the count model and weights from the updated spec (#312)", {
  meta <- yaml::read_yaml(file.path(
    system.file(package = "gsm.kri"),
    "workflow",
    "2_metrics",
    "kri0019.yaml"
  ))$meta

  expect_equal(meta$Model, "Identity")
  expect_equal(meta$Score, "Numerator")
  expect_equal(meta$AnalysisType, "identity")
  expect_equal(meta$Threshold, "1,2")
  expect_equal(meta$Flag, "0,1,2")
  expect_equal(meta$RiskScoreWeight, "0,4,8")
  expect_equal(meta$AccrualThreshold, 1)
  expect_equal(meta$AccrualMetric, "Denominator")
  expect_true(meta$GenerateRiskSignal)
})

test_that("cou0019 aggregates the same numerator by country (#258)", {
  res <- workr::RunWorkflows(
    kri_workflow("cou0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_cou0019$Analysis_Summary

  us <- res[res$GroupID == "US", ]
  expect_equal(us$Numerator, 2)
  expect_equal(us$Denominator, 4)
})

test_that("cou0019 flags the country count of non-starters (#312)", {
  res <- workr::RunWorkflows(
    kri_workflow("cou0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_cou0019$Analysis_Summary

  expect_equal(res$Flag[res$GroupID == "US"], 2)
  expect_equal(res$Flag[res$GroupID == "DE"], 1)
})

test_that("cou0019 stays out of the CM Action Log (#258)", {
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
