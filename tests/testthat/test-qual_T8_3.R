# Double programming: expected counts come from the raw Raw_SUBJ fields, never
# from the metric's own queries.
test_that("Qual: kri0007-2/cou0007-2 numerators and denominators match an independent derivation (#301)", {
  skip_if_not(
    "drv_treatment_discontinuation_dt" %in% names(gsm.core::lSource$Raw_SUBJ),
    "lSource predates the PTD fields"
  )
  wf <- ipns_mapping_workflows()
  skip_if_not(
    "drv_treatment_discontinuation_dt" %in%
      names(gsm.mapping::CombineSpecs(wf)$Raw_SUBJ),
    "installed gsm.mapping spec predates the PTD fields"
  )
  lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(wf))
  mapped <- workr::RunWorkflows(wf, lRaw)
  raw <- gsm.core::lSource$Raw_SUBJ
  dosed <- raw[raw$enrollyn %in% "Y" & raw$drv_ip_dosed %in% "Y", ]

  for (level in list(c("kri0007-2", "invid"), c("cou0007-2", "country"))) {
    want <- dplyr::summarise(
      dplyr::group_by(dosed, GroupID = .data[[level[[2]]]]),
      Numerator = sum(!is.na(.data$drv_treatment_discontinuation_dt)),
      Denominator = dplyr::n()
    )
    got <- workr::RunWorkflows(ptd_workflow(level[[1]]), mapped)[[paste0(
      "Analysis_",
      level[[1]]
    )]]$Analysis_Summary

    expect_setequal(got$GroupID, want$GroupID)
    got <- got[match(want$GroupID, got$GroupID), ]
    expect_equal(got$Numerator, want$Numerator)
    expect_equal(got$Denominator, want$Denominator)
    expect_gt(sum(want$Numerator), 0)
  }
})
