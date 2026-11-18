#' Simulate ActionLogs and Adjusted Risk Scores for simulated studies
#'
#' For each study in `dfResults`, records actions against a random subset of
#' its flagged site KRIs on snapshot dates up to 120 days before the study
#' snapshot, then scores them with the same [gsm.kri::Analyze_ActionRiskScore()]
#' call as the Site KRI Report example. Dates are labelled snapshot-date
#' proxies, so some actions fall outside the 90-day highlight window.
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
  kri_results <- dfResults %>%
    dplyr::filter(
      .data$GroupLevel == "Site",
      !is.na(.data$Flag),
      .data$MetricID %in% weights$MetricID
    )
  keys <- c("StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID")
  states <- c("Open Action", "Closed Action", "No Action", "Awaiting Triage")

  studies <- lapply(split(kri_results, kri_results$StudyID), function(results) {
    snapshot <- unique(results$SnapshotDate)
    flagged <- results[!is.na(results$Flag) & results$Flag != 0, keys, drop = FALSE]
    actions <- flagged[sample.int(nrow(flagged), round(nrow(flagged) * 0.6)), , drop = FALSE]
    actions <- actions %>%
      dplyr::mutate(
        SnapshotDate = snapshot - sample(0:120, dplyr::n(), replace = TRUE),
        State = sample(states, dplyr::n(), replace = TRUE, prob = c(0.35, 0.35, 0.15, 0.15)),
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
