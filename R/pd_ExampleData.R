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
#' @return A named `list` of mapped frames: `Mapped_SUBJ` (every subject plus
#'   `rgmn_dt`), `Mapped_Death` (observed simulated deaths with `deathcls`),
#'   `Mapped_AE` (one synthetic AE row per deceased subject with `subjid`,
#'   `aetoxgr`, `aerel`), and `Mapped_STUDCOMP` (non-death discontinuations
#'   dated inside the window) -- the inputs [pd_Classify()] needs to populate all
#'   five categories.
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

  deathcls_pool <- c("Adverse Event", "Disease Progression", "Other")

  # Follow-up (snapshot - randomization) drives the two "alive" categories, so
  # every subject carries its randomization date.
  Mapped_SUBJ <- subj %>%
    dplyr::mutate(rgmn_dt = rand_date)

  Mapped_Death <- tibble::tibble(
    studyid = subj$studyid[observed],
    subjid = subj$subjid[observed],
    death_dt = rand_date[observed] + death_time[observed],
    death_dy = death_time[observed],
    death = TRUE,
    pd_date = as.Date(NA),
    deathcls = sample(
      deathcls_pool,
      n_obs,
      replace = TRUE,
      prob = c(0.5, 0.3, 0.2)
    )
  )

  # Synthetic AE rows for the deceased subjects so the report's Treatment Related
  # column exercises Yes / No / Unknown. ~40% get a fatal (grade 5) RELATED AE.
  ae_grade <- sample(c(5L, 3L), n_obs, replace = TRUE, prob = c(0.4, 0.6))
  ae_rel <- sample(
    c("RELATED", "NOT RELATED"),
    n_obs,
    replace = TRUE,
    prob = c(0.5, 0.5)
  )
  Mapped_AE <- tibble::tibble(
    subjid = subj$subjid[observed],
    aetoxgr = ae_grade,
    aerel = ae_rel
  )

  # Non-death discontinuations: ~8% of the *surviving* subjects discontinue,
  # dated inside the window so they populate the dark-grey category.
  # mincreated_dts is the studcomp-internal date pd_Classify() uses by default.
  alive <- subj$subjid[!observed]
  n_disc <- max(1, round(0.08 * length(alive)))
  disc_ids <- utils::head(alive, n_disc)
  disc_offset <- round(stats::runif(n_disc, 10, nWindowDays - 5))
  Mapped_STUDCOMP <- tibble::tibble(
    studyid = "ST01",
    subjid = disc_ids,
    compyn = "N",
    compreas = sample(
      c("Withdrawal by Subject", "Lost to Follow-up"),
      n_disc,
      replace = TRUE
    ),
    mincreated_dts = rand_date[match(disc_ids, subj$subjid)] + disc_offset
  )

  list(
    Mapped_SUBJ = Mapped_SUBJ,
    Mapped_Death = Mapped_Death,
    Mapped_AE = Mapped_AE,
    Mapped_STUDCOMP = Mapped_STUDCOMP
  )
}
