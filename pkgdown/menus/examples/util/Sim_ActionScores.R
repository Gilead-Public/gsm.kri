#' Simulate ActionLogs and Adjusted Risk Scores for simulated studies
#'
#' For each study in `dfResults`, records one action against every flagged
#' (non-zero) site KRI, dated 0-89 days before the study snapshot so each falls
#' inside the 90-day highlight window. Most actions are Open or Closed, which
#' keep the KRI's weight; about 10% are No Action, which the disposition
#' policy excludes, so the Adjusted Risk Score differs from the Site Risk
#' Score where those occur. Actions are scored with the same
#' [gsm.kri::Analyze_ActionRiskScore()] call as the Site KRI Report example.
#' Dates are labelled snapshot-date proxies.
#'
#' @param dfResults `data.frame` Results from `Sim_Studies()`.
#' @param dfMetrics `data.frame` Metric metadata used to derive weights.
#' @param seed `integer` Random seed.
#'
#' @return A named list with `dfScores` (one `Analysis_srs0002` row per study
#'   site) and `dfDetail` (stacked per-KRI action detail).
Sim_ActionScores <- function(dfResults, dfMetrics, seed = 280) {
  set.seed(seed)
  weights <- gsm.kri::MakeWeights(dfMetrics)
  # Every flagged site KRI gets an action, including KRIs without risk score
  # weights (e.g. PK, repeat measures): the detail keeps them for highlighting,
  # while only weighted KRIs count toward the score.
  kri_results <- dfResults %>%
    dplyr::filter(
      .data$GroupLevel == "Site",
      !is.na(.data$Flag),
      grepl("^Analysis_kri", .data$MetricID)
    )
  keys <- c("StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID")
  states <- c("Open Action", "Closed Action", "No Action")

  studies <- lapply(split(kri_results, kri_results$StudyID), function(results) {
    snapshot <- unique(results$SnapshotDate)
    actions <- results[results$Flag != 0, keys, drop = FALSE]
    actions <- actions %>%
      dplyr::mutate(
        SnapshotDate = snapshot - sample(0:89, dplyr::n(), replace = TRUE),
        State = sample(states, dplyr::n(), replace = TRUE, prob = c(0.45, 0.45, 0.10)),
        ExtractionDate = snapshot,
        RiskSignalID = paste0(.data$StudyID, "-RS", dplyr::row_number()),
        ActionID = paste0(.data$StudyID, "-A", dplyr::row_number())
      )
    analysis <- gsm.kri::Analyze_ActionRiskScore(
      dfResults = results,
      dfWeights = weights,
      dfActionLog = actions,
      bUseSnapshotDate = TRUE,
      bScoreSnapshotNoAction = TRUE,
      intActionWindowDays = 90L,
      strActionPolicy = "disposition"
    )
    list(
      score = analysis$Analysis_Summary %>%
        dplyr::mutate(StudyID = unique(results$StudyID), SnapshotDate = snapshot),
      detail = analysis$Analysis_ActionRiskScoreDetail
    )
  })

  list(
    dfScores = dplyr::bind_rows(lapply(studies, `[[`, "score")),
    dfDetail = dplyr::bind_rows(lapply(studies, `[[`, "detail"))
  )
}
