#' Calculate an action-aware score and its detail together
#'
#' Computes contributions once and summarizes the same rows into the adjusted
#' score. Source retrieval and persistence remain outside this function.
#'
#' @inheritParams CalculateActionRiskScore
#' @param bUseSnapshotDate Use labelled work-item snapshot date proxies and
#'   recent, unambiguous No Action dispositions. Default FALSE. This does not
#'   manufacture verified decision coverage.
#' @param bScoreSnapshotNoAction Apply snapshot-based No Action exclusions.
#'   Defaults to bUseSnapshotDate. FALSE retains displayed proxy dates without
#'   using them to exclude contributions.
#' @return A list containing `Analysis_Summary` and
#'   `Analysis_ActionRiskScoreDetail`, retaining the maximum-weight denominator.
#' @export
Analyze_ActionRiskScore <- function(
  dfResults, dfWeights, dfActionLog,
  bUseSnapshotDate = FALSE, intActionWindowDays = 90L,
  strActionPolicy = "disposition", bActionHistoryComplete = FALSE,
  dActionExtractionDate = NULL, dActionAsOfDate = NULL,
  strMetricID = "Analysis_srs0002", bScoreSnapshotNoAction = bUseSnapshotDate
) {
  if (!is.logical(bUseSnapshotDate) || length(bUseSnapshotDate) != 1L || is.na(bUseSnapshotDate)) {
    stop("bUseSnapshotDate must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.logical(bScoreSnapshotNoAction) || length(bScoreSnapshotNoAction) != 1L || is.na(bScoreSnapshotNoAction))
    stop("bScoreSnapshotNoAction must be TRUE or FALSE.", call. = FALSE)
  if (is.null(dActionExtractionDate) && is.data.frame(dfActionLog) && nrow(dfActionLog) > 0L &&
      inherits(dfActionLog$ExtractionDate, "Date")) dActionExtractionDate <- max(dfActionLog$ExtractionDate)
  detail <- MakeActionRiskScoreDetail(
    dfResults, dfWeights, dfActionLog, intActionWindowDays = intActionWindowDays,
    strActionPolicy = strActionPolicy, bActionHistoryComplete = bActionHistoryComplete,
    dActionExtractionDate = dActionExtractionDate, dActionAsOfDate = dActionAsOfDate,
    strMetricID = strMetricID
  )
  if (bUseSnapshotDate) detail <- .apply_snapshot_risk_policy(detail, dfActionLog,
    if (bScoreSnapshotNoAction) strActionPolicy else "display-only")
  score <- SummarizeRiskScore(dplyr::filter(detail, !is.na(.data$Weight), !is.na(.data$WeightMax)),
    "EffectiveWeight", strMetricID)
  list(Analysis_Summary = score, Analysis_ActionRiskScoreDetail = detail)
}

.action_snapshot_summary <- function(actions, assessment, extraction) {
  actions <- actions[actions$ExtractionDate <= extraction, , drop = FALSE]
  if (nrow(actions)) {
    actions <- actions[actions$ExtractionDate == max(actions$ExtractionDate) &
      actions$SnapshotDate <= assessment, , drop = FALSE]
  }
  if (!nrow(actions)) {
    summary <- actions[FALSE, .risk_score_action_join_key, drop = FALSE]
    summary$SnapshotObservedState <- character()
    summary$SnapshotScoreDate <- as.Date(character())
    summary$SnapshotAddressedState <- character()
    return(summary)
  }
  collapse_states <- function(states) {
    states <- sort(unique(states[!is.na(states)]))
    if (length(states)) paste(states, collapse = ", ") else NA_character_
  }
  actions %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(.risk_score_action_join_key))) %>%
    dplyr::summarise(
      SnapshotObservedState = collapse_states(.data$State[.data$SnapshotDate == max(.data$SnapshotDate)]),
      SnapshotScoreDate = {
        dates <- .data$SnapshotDate[.data$State %in% c("Open Action", "Closed Action", "No Action")]
        if (length(dates)) max(dates) else as.Date(NA_character_)
      },
      SnapshotAddressedState = collapse_states(.data$State[.data$SnapshotDate == .data$SnapshotScoreDate &
        .data$State %in% c("Open Action", "Closed Action", "No Action")]),
      .groups = "drop"
    )
}

.apply_snapshot_risk_policy <- function(detail, actions, policy) {
  assessment <- unique(detail$ActionAsOfDate)
  extraction <- unique(detail$ActionExtractionDate)
  cutoff <- if (length(extraction) == 1L && !is.na(extraction)) extraction else assessment
  observed <- .action_snapshot_summary(actions, min(assessment, detail$SnapshotDate), cutoff)
  detail <- dplyr::left_join(detail, observed, by = .risk_score_action_join_key)
  proxy <- is.na(detail$LastActionedDate) & !is.na(detail$SnapshotScoreDate)
  detail$ActionDateIsProxy <- proxy
  detail$LastActionedDate[proxy] <- detail$SnapshotScoreDate[proxy]
  detail$DaysSinceAction[proxy] <- as.integer(assessment - detail$SnapshotScoreDate[proxy])
  detail$ActionedDateSource[proxy] <- "ADO.Custom.SnapshotDate (proxy; not a user-action timestamp)"
  observed_state <- proxy | is.na(detail$ActionState)
  detail$ActionState[observed_state] <- detail$SnapshotObservedState[observed_state]
  detail$SnapshotScoreAge <- as.integer(assessment - detail$SnapshotScoreDate)
  candidate <- detail$SnapshotObservedState %in% "No Action" & detail$SnapshotAddressedState %in% "No Action"
  detail$SnapshotNoActionCandidate <- candidate
  weighted <- !is.na(detail$Weight) & !is.na(detail$WeightMax)
  positive <- weighted & !is.na(detail$EffectiveWeight) & detail$EffectiveWeight > 0
  age <- detail$SnapshotScoreAge
  recent <- !is.na(age) & age >= 0 & age <= detail$ActionWindowDays
  eligible <- policy == "disposition" & candidate & recent & positive
  reason <- rep("Latest work-item state is not unambiguous No Action", nrow(detail))
  reason[candidate & is.na(age)] <- "Missing snapshot scoring date"
  reason[candidate & !is.na(age) & age < 0] <- "Future snapshot"
  reason[candidate & !is.na(age) & age > detail$ActionWindowDays] <- "No Action snapshot is outside the scoring window"
  if (policy != "disposition") reason[] <- "Snapshot No Action scoring disabled by policy"
  reason[!weighted] <- "KRI has no scoring weight"
  reason[weighted & !positive] <- "Contribution already zero or unavailable"
  reason[eligible] <- "No Action within snapshot window (snapshot-date policy)"
  detail$SnapshotDecisionReason <- reason
  detail$SnapshotDecisionExcluded <- eligible
  detail$ActionReason[positive] <- reason[positive]
  detail$ActionFactor[eligible] <- 0
  detail$EffectiveWeight[eligible] <- 0
  detail$ActionState[eligible] <- "No Action"
  detail
}