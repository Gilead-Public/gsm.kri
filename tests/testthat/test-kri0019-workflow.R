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

test_that("kri0019 leaves a site below the accrual gate unscored (#258)", {
  res <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    list(Mapped_IPNS = ipns_fixture())
  )$Analysis_kri0019$Analysis_Summary

  # I2 has one numerator subject, below AccrualThreshold: 2.
  i2 <- res[res$GroupID == "I2", ]
  expect_true(is.na(i2$Score))
  expect_true(is.na(i2$Flag))
})

test_that("kri0019 flags only high rates (#258)", {
  meta <- yaml::read_yaml(file.path(
    system.file(package = "gsm.kri"),
    "workflow",
    "2_metrics",
    "kri0019.yaml"
  ))$meta

  expect_equal(meta$Threshold, "2,3")
  expect_equal(meta$Flag, "0,1,2")
  expect_true(meta$GenerateRiskSignal)
})
