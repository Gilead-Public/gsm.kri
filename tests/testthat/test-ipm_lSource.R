# Integration check on the bundled reference data: the report's statuses must
# agree with the IPNS and PTD metrics computed from the same mapped data.
ipm_lsource_mapped <- function() {
  wf <- workr::MakeWorkflowList(
    strNames = c("SUBJ", "STUDCOMP", "IPNS"),
    strPath = file.path(
      system.file(package = "gsm.mapping"),
      "workflow",
      "1_mappings"
    ),
    bExact = TRUE
  )
  lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(wf))
  workr::RunWorkflows(wf, lRaw)
}

test_that("lSource statuses agree with kri0007-2 and kri0019 (#320, #332)", {
  TestAtLogLevel()
  skip_if_not(
    all(
      c("drv_kit_assigned", "drv_drg_completion") %in%
        names(gsm.core::lSource$Raw_SUBJ)
    ),
    "lSource predates the IPNS kit field or drv_drg_completion"
  )
  skip_if_not(
    "drv_drg_completion" %in%
      names(
        gsm.mapping::CombineSpecs(workr::MakeWorkflowList(
          strNames = "SUBJ",
          strPath = file.path(
            system.file(package = "gsm.mapping"),
            "workflow",
            "1_mappings"
          )
        ))$Raw_SUBJ
      ),
    "installed gsm.mapping spec predates drv_drg_completion"
  )
  skip_if_not(
    file.exists(file.path(
      system.file(package = "gsm.kri"),
      "workflow",
      "2_metrics",
      "kri0007-2.yaml"
    )),
    "kri0007-2 not on this branch"
  )

  mapped <- ipm_lsource_mapped()
  ipns <- mapped$Mapped_IPNS
  # lSource has no dosed "today"; not-dosed rows count days up to its as-of date.
  dAsOf <- max(
    ipns$drv_enrollment_dt + ipns$drv_days_lapsed_since_enrl - 1L,
    na.rm = TRUE
  )
  expect_warning(
    dfIPM <- ipm_ClassifyParticipants(
      ipns,
      mapped$Mapped_SUBJ,
      mapped$Mapped_STUDCOMP,
      dAsOf
    ),
    NA
  )

  expect_setequal(
    as.character(unique(dfIPM$status)),
    setdiff(names(ipm_StatusColors()), "Unrecognized status")
  )
  expect_equal(nrow(dfIPM), nrow(ipns))
  expect_true(all(
    stats::na.omit(ipns$ipns_status) %in% c("Dosed", names(ipm_StatusColors()))
  ))
  bFirstDose <- !is.na(dfIPM$days_to_first_dose)
  expect_equal(
    dfIPM$days_to_first_dose[bFirstDose],
    ipns$drv_enrl_first_dose_days[match(dfIPM$subjid[bFirstDose], ipns$subjid)]
  )
  expect_true(all(dfIPM$days_to_event >= 1))

  metrics <- workr::RunWorkflows(
    workr::MakeWorkflowList(
      strNames = c("kri0007-2", "kri0019"),
      strPath = file.path(
        system.file(package = "gsm.kri"),
        "workflow",
        "2_metrics"
      ),
      bExact = TRUE,
      # kri0007-2 ships inactive.
      bActiveOnly = FALSE
    ),
    mapped
  )
  by_site <- function(bNumerator, bDenominator) {
    df <- tibble::tibble(GroupID = dfIPM$invid, numerator = bNumerator)[
      bDenominator,
    ]
    dplyr::summarise(
      dplyr::group_by(df, .data$GroupID),
      Numerator = sum(.data$numerator),
      Denominator = dplyr::n()
    )
  }
  checks <- list(
    `kri0007-2` = by_site(
      dfIPM$status %in% "Premature treatment discontinuation",
      dfIPM$dosed %in% "Y"
    ),
    kri0019 = by_site(
      dfIPM$status %in%
        c(
          "Potential IP non-starter - outside window",
          "Confirmed IP non-starter"
        ),
      rep(TRUE, nrow(dfIPM))
    )
  )
  for (id in names(checks)) {
    want <- checks[[id]]
    got <- metrics[[paste0("Analysis_", id)]]$Analysis_Transformed
    got <- got[match(want$GroupID, got$GroupID), ]
    expect_equal(got$Numerator, want$Numerator, label = paste(id, "numerators"))
    expect_equal(
      got$Denominator,
      want$Denominator,
      label = paste(id, "denominators")
    )
    expect_gt(sum(want$Numerator), 0)
  }
})
