#' Mock the gsm.mapping PR1 `complete_death()` AE-match extension (example only)
#'
#' @description
#' Enriches `Mapped_Death` with `death_reason` / `treatment_related` /
#' `ae_pt_at_death`, reproducing gsm.mapping PR1 (spec section 7.1). Each death is
#' matched to its most likely fatal AE: CTCAE Grade 5, OR an AE that ended within
#' +/-1 day of death. Highest grade wins; ties break to earliest start. This is a
#' temporary stand-in for the unmerged PR1 used only by the Premature Deaths
#' example article. Delete it (and its call + test) once PR1 merges.
#'
#' @param dfDeath `data.frame` Mapped death data (`subjid`, `death_dt`, ...).
#' @param dfAE `data.frame` Mapped AE data.
#' @param dfStudComp `data.frame` Mapped study-completion data (`subjid`, `compreas`).
#'
#' @return `dfDeath` with `death_reason` / `treatment_related` / `ae_pt_at_death`.
#' @noRd
pd_MockCompleteDeathExtension <- function(dfDeath, dfAE, dfStudComp) {
  fatal_ae <- dfAE %>%
    dplyr::inner_join(
      dfDeath %>% dplyr::select("subjid", "death_dt"),
      by = "subjid"
    ) %>%
    dplyr::filter(
      .data$aetoxgr == 5 |
        (!is.na(.data$aeen_dt) &
          abs(as.numeric(.data$aeen_dt - .data$death_dt)) <= 1)
    ) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::arrange(dplyr::desc(.data$aetoxgr), .data$aest_dt) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup() %>%
    dplyr::transmute(
      subjid = .data$subjid,
      ae_pt_at_death = .data$mdrpt_nsv,
      ae_rel = .data$aerel
    )

  dfStudCompReason <- dfStudComp %>%
    dplyr::select("subjid", "compreas") %>%
    dplyr::distinct(.data$subjid, .keep_all = TRUE)

  dfDeath %>%
    dplyr::left_join(fatal_ae, by = "subjid") %>%
    dplyr::left_join(dfStudCompReason, by = "subjid") %>%
    dplyr::mutate(
      treatment_related = .data$ae_rel %in% "Y", # aerel Y/N; related = "Y"
      death_reason = dplyr::coalesce(
        .data$ae_pt_at_death,
        .data$compreas,
        "Unknown"
      )
    ) %>%
    # Illustrative relabel of clindata's synthetic AE preferred-term codes
    # (term1 / term2) so the sample report's reason chart reads sensibly.
    # Mock presentation only.
    dplyr::mutate(
      death_reason = dplyr::recode(
        .data$death_reason,
        term1 = "Cardiac arrest",
        term2 = "Sepsis"
      )
    ) %>%
    dplyr::select(-"ae_rel")
}
