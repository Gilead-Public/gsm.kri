# Double programming: the expected numerator is derived independently from the
# status STRINGS, never from ipns_status_ord, so a recode bug cannot cancel out.
test_that("Qual: kri0019/cou0019 numerators match an independent derivation (#258)", {
  skip_if_not(
    "drv_ip_nonstarter_status" %in% names(gsm.core::lSource$Raw_SUBJ),
    "lSource predates the upstream drv_ fields"
  )

  wf <- ipns_mapping_workflows()
  lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(wf))
  mapped <- workr::RunWorkflows(wf, lRaw)

  expected <- mapped$Mapped_SUBJ[
    mapped$Mapped_SUBJ$drv_ip_nonstarter_status %in%
      c(
        "Confirmed Non-Starter",
        "Potential Non-Starter outside window"
      ),
  ]

  # RunWorkflows keys results by "<meta$Type>_<meta$ID>", not the bare ID.
  site <- workr::RunWorkflows(
    kri_workflow("kri0019"),
    mapped
  )$Analysis_kri0019$Analysis_Summary
  country <- workr::RunWorkflows(
    kri_workflow("cou0019"),
    mapped
  )$Analysis_cou0019$Analysis_Summary

  expect_equal(sum(site$Numerator), nrow(expected))
  expect_equal(sum(country$Numerator), nrow(expected))
})
