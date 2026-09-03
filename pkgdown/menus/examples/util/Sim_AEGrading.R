#### Helper Function: Sim_AEGrading ####

#' Simulate Site-Level AE Severity Grading Behaviour
#'
#' Overwrites the severity grade column of a mapped AE table so that a handful of
#' sites grade adverse events differently from the rest of the study.
#'
#' The bundled `gsm.core` example data has a realistic study-wide grade
#' distribution, but grades are assigned independently of site, so no site
#' deviates from the study and the AE Grading report has nothing to find. This
#' helper keeps the real subject/site structure and per-site AE burden and
#' redraws `aetoxgr` from the study's own grade distribution, tilted per site.
#'
#' Behaviour is an ordinal tilt on the baseline grade probabilities: positive
#' shifts probability mass toward Grade 5, negative toward Grade 1. Most sites
#' get a small random tilt; a few are given deliberate patterns:
#'   - **Global under-graders** report almost everything as Grade 1.
#'   - **Global over-graders** report an inflated share of Grade 3+ events.
#'
#' @param dfAE Mapped AE data frame with `subjid` and `aetoxgr`
#' @param dfSubj Mapped subject data frame with `subjid` and `invid`
#' @param nScale AE volume multiplier, so more sites clear the report's minimum
#'   graded-AE threshold (default: 3)
#' @param nUnder Number of global under-grading sites to plant (default: 4)
#' @param nOver Number of global over-grading sites to plant (default: 3)
#' @param seed Random seed for reproducibility (default: 8675309)
#'
#' @return A named list with two elements:
#'   - AE: the simulated AE data frame, same columns as `dfAE`
#'   - truth: one row per planted site, with the grading pattern it was given
Sim_AEGrading <- function(
  dfAE,
  dfSubj,
  nScale = 3L,
  nUnder = 4,
  nOver = 3,
  seed = 8675309
) {
  set.seed(seed)

  ae <- dfAE %>%
    dplyr::slice(rep(seq_len(dplyr::n()), nScale)) %>%
    dplyr::left_join(dfSubj %>% dplyr::select("subjid", "invid"), by = "subjid")

  # Baseline = the study's own grade distribution, so the simulated study looks
  # like the source data in aggregate.
  vBase <- dfAE$aetoxgr %>%
    as.integer() %>%
    factor(levels = 1:5) %>%
    table() %>%
    as.numeric()
  vBase <- vBase / sum(vBase)

  dfSites <- ae %>%
    dplyr::filter(!is.na(.data$invid)) %>%
    dplyr::count(.data$invid, name = "nAE") %>%
    dplyr::arrange(dplyr::desc(.data$nAE))

  # Only plant behaviour at sites with enough volume to be evaluable.
  vElig <- dfSites %>% dplyr::filter(.data$nAE >= 45) %>% dplyr::pull("invid")
  vPicked <- sample(vElig, min(nUnder + nOver, length(vElig)))
  vUnder <- vPicked[seq_len(nUnder)]
  vOver <- vPicked[nUnder + seq_len(nOver)]

  vSiteDelta <- stats::setNames(
    stats::rnorm(nrow(dfSites), 0, .15),
    dfSites$invid
  )
  vSiteDelta[vUnder] <- -1.15
  vSiteDelta[vOver] <- 1.05

  dfTruth <- dplyr::bind_rows(
    tibble::tibble(invid = vUnder, Pattern = "Global under-grader"),
    tibble::tibble(invid = vOver, Pattern = "Global over-grader")
  )

  vDelta <- dplyr::coalesce(unname(vSiteDelta[ae$invid]), 0)
  mP <- matrix(vBase, nrow = nrow(ae), ncol = 5, byrow = TRUE) *
    exp(outer(vDelta, (1:5) - 3))
  mP <- mP / rowSums(mP)

  ae$aetoxgr <- max.col(
    t(apply(mP, 1, cumsum)) >= stats::runif(nrow(mP)),
    ties.method = "first"
  )

  list(
    AE = ae %>% dplyr::select(dplyr::all_of(names(dfAE))),
    truth = dfTruth
  )
}
