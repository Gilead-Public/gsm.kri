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

  # Deterministic per-subject selection: prefer "Death" over other non-missing
  # compreas values, then other non-missing, then missing. This avoids
  # order-dependent results when dfStudComp has multiple rows per subject.
  dfStudCompReason <- dfStudComp %>%
    dplyr::select("subjid", "compreas") %>%
    dplyr::mutate(
      .priority = dplyr::case_when(
        .data$compreas == "Death" ~ 1L,
        !is.na(.data$compreas) ~ 2L,
        .default = 3L
      )
    ) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::arrange(.data$.priority, .by_group = TRUE) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup() %>%
    dplyr::select(-".priority")

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

#' Simulate a realistic premature-death cohort (example only)
#'
#' @description
#' clindata's real randomization dates sit ~a decade before the snapshot, so the
#' handful of real premature deaths land >10 years out and off-scale on the study
#' scatter. Rather than place points on an artificial even grid, this simulates
#' the trial dynamics that actually shape the scatter:
#'
#' * Accrual (-> y-axis): each subject gets a randomization date drawn from an
#'   accelerating-then-steady accrual curve over a 5-year window ending at the
#'   snapshot. Time-on-study (snapshot - randomization) IS the scatter's y.
#' * Mortality (-> x-axis): time from randomization to death ~ Weibull with a
#'   slightly decreasing hazard (early-death emphasis), calibrated to a ~6%
#'   in-window death rate.
#' * Censoring (-> shape): a death is observed only if it occurred before the
#'   snapshot (`death_dy <= time-on-study`), emptying the lower-right of the
#'   scatter and giving the characteristic wedge along y >= x.
#'
#' @param dfSubj `data.frame` Enrolled subjects (`studyid`, `subjid`).
#' @param nWindowDays `numeric` Premature-death window (calibration target for mortality).
#' @param seed `integer` RNG seed for reproducibility. Default `2026`.
#' @param snapshot_date `Date` Reporting snapshot. Default `Sys.Date()`
#'   (the gsm.reporting `BindResults` default).
#'
#' @return A `tibble` of observed simulated deaths matching the enriched schema
#'   returned by `pd_MockCompleteDeathExtension()` (`Mapped_Death` plus
#'   `ae_pt_at_death`, `compreas`, `treatment_related`, `death_reason`).
#' @noRd
pd_SimulatePrematureDeathCohort <- function(
  dfSubj,
  nWindowDays,
  seed = 2026,
  snapshot_date = Sys.Date()
) {
  set.seed(seed)
  study_duration <- 5 * 365 # max time-on-study / accrual window (days)

  subj <- dfSubj %>% dplyr::distinct(.data$subjid, .keep_all = TRUE)
  n_subj <- nrow(subj)

  # Accrual: accelerating (concave) enrolment -> more subjects randomized
  # recently -> shorter time-on-study.
  accrual_time <- study_duration * stats::runif(n_subj)^(1 / 1.6)
  time_on_study <- study_duration - accrual_time # = snapshot - randomization
  rand_date <- snapshot_date - round(time_on_study)

  # Mortality: Weibull time-to-death (shape < 1 => early-death emphasis), scaled
  # so ~6% of subjects die within the window.
  wb_shape <- 0.9
  wb_scale <- nWindowDays / (-log(1 - 0.06))^(1 / wb_shape)
  death_time <- round(stats::rweibull(
    n_subj,
    shape = wb_shape,
    scale = wb_scale
  ))

  # Censoring: observe a death only if it happened before the snapshot.
  observed <- death_time >= 1 & death_time <= time_on_study
  n_obs <- sum(observed)

  reasons <- c("Cardiac arrest", "Sepsis", "Disease progression", "Unknown")
  tibble::tibble(
    studyid = subj$studyid[observed],
    subjid = subj$subjid[observed],
    death_dt = rand_date[observed] + death_time[observed],
    death_dy = death_time[observed],
    death = TRUE,
    pd_date = as.Date(NA),
    ae_pt_at_death = NA_character_,
    compreas = NA_character_,
    treatment_related = stats::runif(n_obs) < 0.35,
    death_reason = sample(
      reasons,
      n_obs,
      replace = TRUE,
      prob = c(0.30, 0.25, 0.30, 0.15)
    )
  )
}
