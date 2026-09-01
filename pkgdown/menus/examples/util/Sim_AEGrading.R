#### Helper Function: Sim_AEGrading ####

#' Simulate AE Severity Grading Data
#'
#' Overwrites the severity grade and preferred term columns of a mapped AE table
#' with a realistic grading scenario, for demonstration purposes.
#'
#' The bundled `gsm.core` example data carries only two placeholder preferred
#' terms (`term1`, `term2`) and no site-level grading behaviour, so it cannot
#' demonstrate the term-level half of the AE Grading report. This helper keeps
#' the real subject/site structure and per-site AE burden but replaces
#' `mdrpt_nsv` / `mdrsoc_nsv` with twelve realistic MedDRA-style terms and draws
#' `aetoxgr` from term-specific baseline distributions.
#'
#' A small number of sites are given deliberate grading behaviour so the report
#' has something to find:
#'   - **Global under-graders** report almost everything as Grade 1.
#'   - **Global over-graders** report an inflated share of Grade 3+ events.
#'   - **Term-specific inconsistent graders** look unremarkable in aggregate but
#'     grade individual preferred terms very differently from the study. These
#'     are invisible to the site-level `kri0016` / `kri0017` metrics and exist to
#'     show what the term-level analysis adds.
#'
#' @param dfAE Mapped AE data frame with `subjid`, `aetoxgr`, `mdrpt_nsv` and `mdrsoc_nsv`
#' @param dfSubj Mapped subject data frame with `subjid` and `invid`
#' @param nScale AE volume multiplier, so site/term cells clear the minimum volume
#'   thresholds the report applies (default: 3)
#' @param seed Random seed for reproducibility (default: 8675309)
#'
#' @return A named list with two elements:
#'   - AE: the simulated AE data frame, same columns as `dfAE`
#'   - truth: one row per planted site, with the grading pattern it was given
Sim_AEGrading <- function(
  dfAE,
  dfSubj,
  nScale = 3L,
  seed = 8675309
) {
  set.seed(seed)

  # Preferred terms, their study-wide frequency, and baseline P(Grade 1..5).
  # Mild GI/constitutional terms skew low; haematology terms skew high.
  lPT <- tibble::tribble(
    ~PT,                  ~w,   ~g1,  ~g2,  ~g3,  ~g4,  ~g5,
    "Nausea",             .16,  .55,  .30,  .11,  .03,  .01,
    "Fatigue",            .14,  .50,  .33,  .13,  .03,  .01,
    "Headache",           .12,  .65,  .26,  .07,  .015, .005,
    "Diarrhoea",          .10,  .48,  .32,  .16,  .03,  .01,
    "Vomiting",           .09,  .45,  .33,  .17,  .04,  .01,
    "Anaemia",            .08,  .30,  .35,  .25,  .08,  .02,
    "Neutropenia",        .07,  .18,  .27,  .35,  .17,  .03,
    "Pyrexia",            .06,  .52,  .32,  .13,  .02,  .01,
    "Rash",               .06,  .58,  .28,  .11,  .02,  .01,
    "Decreased appetite", .05,  .60,  .28,  .10,  .015, .005,
    "Thrombocytopenia",   .04,  .32,  .33,  .24,  .09,  .02,
    "ALT increased",      .03,  .40,  .32,  .20,  .06,  .02
  )

  vSOC <- c(
    "Nausea" = "Gastrointestinal disorders",
    "Vomiting" = "Gastrointestinal disorders",
    "Diarrhoea" = "Gastrointestinal disorders",
    "Fatigue" = "General disorders",
    "Pyrexia" = "General disorders",
    "Headache" = "Nervous system disorders",
    "Anaemia" = "Blood and lymphatic system disorders",
    "Neutropenia" = "Blood and lymphatic system disorders",
    "Thrombocytopenia" = "Blood and lymphatic system disorders",
    "Rash" = "Skin and subcutaneous tissue disorders",
    "Decreased appetite" = "Metabolism and nutrition disorders",
    "ALT increased" = "Investigations"
  )

  ae <- dfAE %>% dplyr::slice(rep(seq_len(dplyr::n()), nScale))
  ae$mdrpt_nsv <- sample(lPT$PT, nrow(ae), replace = TRUE, prob = lPT$w)
  ae$mdrsoc_nsv <- unname(vSOC[ae$mdrpt_nsv])

  ae <- ae %>%
    dplyr::left_join(dfSubj %>% dplyr::select("subjid", "invid"), by = "subjid")

  dfSites <- ae %>%
    dplyr::filter(!is.na(.data$invid)) %>%
    dplyr::count(.data$invid, name = "nAE") %>%
    dplyr::arrange(dplyr::desc(.data$nAE))

  # Only plant behaviour at sites with enough volume to be evaluable.
  vElig <- dfSites %>% dplyr::filter(.data$nAE >= 45) %>% dplyr::pull("invid")
  vPicked <- sample(vElig, min(12, length(vElig)))
  vUnder <- vPicked[1:4]
  vOver <- vPicked[5:7]
  vPTonly <- vPicked[8:12]

  # Grading behaviour is an ordinal tilt on the baseline grade probabilities:
  # positive shifts mass toward Grade 5, negative toward Grade 1.
  vSiteDelta <- stats::setNames(
    stats::rnorm(nrow(dfSites), 0, .15),
    dfSites$invid
  )
  vSiteDelta[vUnder] <- -1.15
  vSiteDelta[vOver] <- 1.05

  # Balanced +/- shifts, so these sites look normal in aggregate but are clearly
  # inconsistent term by term.
  dfPTShift <- purrr::map_dfr(vPTonly, function(s) {
    tibble::tibble(
      invid = s,
      PT = sample(lPT$PT[1:8], 4),
      d = c(2.0, 2.0, -2.0, -2.0)
    )
  })

  dfTruth <- dplyr::bind_rows(
    tibble::tibble(invid = vUnder, Pattern = "Global under-grader"),
    tibble::tibble(invid = vOver, Pattern = "Global over-grader"),
    tibble::tibble(invid = vPTonly, Pattern = "Term-specific inconsistency")
  )

  ae <- ae %>%
    dplyr::left_join(lPT %>% dplyr::select("PT", "g1":"g5"), by = c("mdrpt_nsv" = "PT")) %>%
    dplyr::left_join(dfPTShift, by = c("invid", "mdrpt_nsv" = "PT")) %>%
    dplyr::mutate(
      delta = dplyr::coalesce(unname(vSiteDelta[.data$invid]), 0) +
        dplyr::coalesce(.data$d, 0),
      delta = dplyr::if_else(is.na(.data$delta), 0, .data$delta)
    )

  mP <- as.matrix(ae[, c("g1", "g2", "g3", "g4", "g5")]) *
    exp(outer(ae$delta, (1:5) - 3))
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
