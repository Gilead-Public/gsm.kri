# Qualification (double programming) for the IP non-starter metrics
# kri0016 / cou0016 / pat0016 over gsm.core::lSource-derived data.
# Self-contained: builds the mapping -> metric pipeline directly from lSource so
# it does not depend on the cached qualification fixture. Requires the co-landing
# foundation (gsm.mapping#139 specs + NonStarter.yaml, and the regenerated
# gsm.core::lSource from gsm.core#156, whose STUDCOMP rows carry compreas).

NEVER_DOSED <- "Subject Never Dosed with Study Drug"

test_that("Qual: IP non-starter metrics count confirmed non-starters over lSource-derived data {#258}", {
  # sdrgreas is the only sentinel that distinguishes the regenerated lSource from
  # the shipped one: compreas exists in both, so guarding on it would let this
  # test run against un-regenerated data and fail instead of skipping.
  skip_if_not(
    "sdrgreas" %in% names(gsm.core::lSource$Raw_SDRGCOMP),
    "requires the regenerated gsm.core::lSource (gsm.core#156)"
  )

  lSource <- gsm.core::lSource
  map_dir <- file.path(
    system.file(package = "gsm.mapping"),
    "workflow",
    "1_mappings"
  )
  skip_if_not(
    file.exists(file.path(map_dir, "NonStarter.yaml")),
    "requires gsm.mapping#139 (NonStarter.yaml)"
  )

  # Build Mapped_NonStarter through the real mapping pipeline.
  map_wf <- workr::MakeWorkflowList(
    strNames = c("SUBJ", "SDRGCOMP", "STUDCOMP", "NonStarter"),
    strPath = map_dir
  )
  lData <- list(
    Raw_SUBJ = lSource$Raw_SUBJ,
    Raw_SDRGCOMP = dplyr::mutate(
      lSource$Raw_SDRGCOMP,
      phase = as.character(phase)
    ),
    Raw_STUDCOMP = lSource$Raw_STUDCOMP
  )
  raw <- gsm.mapping::Ingest(lData, gsm.mapping::CombineSpecs(map_wf))
  mapped <- workr::RunWorkflows(map_wf, raw)
  ns <- mapped$Mapped_NonStarter
  expect_true(all(
    c("subjid", "invid", "country", "confirmed_nonstarter") %in% names(ns)
  ))

  # Independent double-program of the confirmed-non-starter set.
  subj <- mapped$Mapped_SUBJ
  never_dosed <- subj$subjid[is.na(subj$firstdosedate)]
  sdrg <- mapped$Mapped_SDRGCOMP
  sdrg_ns <- sdrg$subjid[
    !is.na(sdrg$sdrgreas) & toupper(sdrg$sdrgreas) == toupper(NEVER_DOSED)
  ]
  stud <- mapped$Mapped_STUDCOMP
  stud_ns <- stud$subjid[!is.na(stud$compreas) & trimws(stud$compreas) != ""]
  indep_confirmed <- length(intersect(never_dosed, union(sdrg_ns, stud_ns)))

  expect_gt(indep_confirmed, 0)
  expect_equal(sum(ns$confirmed_nonstarter), indep_confirmed)

  # Metrics run end-to-end and emit the standard analysis columns; the total
  # numerator at each level equals the confirmed count.
  lData_ns <- c(mapped, list(Mapped_NonStarter = ns))
  wfs <- workr::MakeWorkflowList(
    c("kri0016", "cou0016", "pat0016"),
    GetDefaultKRIPath(),
    bExact = TRUE
  )
  out <- purrr::map(wfs, ~ gsm.core::RunWorkflow(.x, lData_ns)$Analysis_Summary)
  purrr::walk(
    out,
    ~ expect_true(all(c("GroupID", "Numerator", "Denominator") %in% names(.x)))
  )
  expect_equal(sum(out$kri0016$Numerator), indep_confirmed)
  expect_equal(sum(out$cou0016$Numerator), indep_confirmed)
  expect_equal(sum(out$pat0016$Numerator), indep_confirmed)
  expect_equal(nrow(out$pat0016), nrow(subj))
})
