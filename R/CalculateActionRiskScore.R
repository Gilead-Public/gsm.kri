#' Calculate an action-status-weighted Site Risk Score
#'
#' Applies Central Monitoring ActionLog states to existing KRI flag weights.
#' Action factors affect only numerator contributions; the denominator remains
#' the full maximum-risk denominator used by [CalculateRiskScore()].
#'
#' @param dfResults Current persisted KRI result rows. Must contain one
#'   `StudyID` and one `SnapshotDate` plus `GroupLevel`, `GroupID`, `MetricID`,
#'   and `Flag`.
#' @param dfWeights Risk score weights with `MetricID`, `Flag`, `Weight`, and
#'   `WeightMax`.
#' @param dfActionLog Scoring-ready ActionLog rows with the five-column result
#'   key, `State`, and `ExtractionDate`. The scoring key must be unique.
#' @param lActionFactors Named numeric state-factor mapping. Defaults to include
#'   open, closed, and awaiting-triage findings and exclude no-action findings.
#' @param strMissingState Policy for a missing action state on a nonzero KRI
#'   weight: stop with an error, include the weight, or exclude the weight.
#' @param strMetricID Metric ID assigned to the action-weighted score.
#'
#' @return A canonical risk score data frame with the same output schema as
#'   [CalculateRiskScore()].
#' @export
CalculateActionRiskScore <- function(
  dfResults,
  dfWeights,
  dfActionLog,
  lActionFactors = c(
    "Open Action" = 1,
    "Closed Action" = 1,
    "Awaiting Triage" = 1,
    "No Action" = 0
  ),
  strMissingState = c("error", "include", "exclude"),
  strMetricID = "Analysis_srs0002"
) {
  strMissingState <- match.arg(strMissingState)
  result_context <- .validate_single_study_snapshot(dfResults, "dfResults")

  required_action_columns <- c(
    .risk_score_action_key, "State", "ExtractionDate"
  )
  if (!is.data.frame(dfActionLog) ||
      !all(required_action_columns %in% names(dfActionLog))) {
    missing <- setdiff(required_action_columns, names(dfActionLog))
    stop(
      "dfActionLog is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  action_context <- .validate_single_study_snapshot(
    dfActionLog,
    "dfActionLog",
    allow_empty = TRUE
  )
  if (!is.null(action_context) &&
      (!identical(as.character(action_context$StudyID), as.character(result_context$StudyID)) ||
        !identical(action_context$SnapshotDate, result_context$SnapshotDate))) {
    stop(
      "dfResults and dfActionLog must represent the same StudyID and SnapshotDate.",
      call. = FALSE
    )
  }
  if (any(!stats::complete.cases(dfResults[, .risk_score_action_key]))) {
    stop("dfResults scoring key columns must not contain missing values.", call. = FALSE)
  }
  if (nrow(dfActionLog) > 0L &&
      any(!stats::complete.cases(dfActionLog[, .risk_score_action_key]))) {
    stop("dfActionLog scoring key columns must not contain missing values.", call. = FALSE)
  }
  if (!inherits(dfResults$SnapshotDate, "Date") ||
      !inherits(dfActionLog$SnapshotDate, "Date") ||
      !inherits(dfActionLog$ExtractionDate, "Date")) {
    stop(
      "SnapshotDate and ExtractionDate columns must use class Date.",
      call. = FALSE
    )
  }
  if (nrow(dfActionLog) > 0L && anyNA(dfActionLog$ExtractionDate)) {
    stop("dfActionLog ExtractionDate must not be missing.", call. = FALSE)
  }
  if (nrow(dfActionLog) > 0L &&
      any(dfActionLog$ExtractionDate < dfActionLog$SnapshotDate)) {
    stop("dfActionLog ExtractionDate must not predate SnapshotDate.", call. = FALSE)
  }
  if (any(duplicated(dfActionLog[, .risk_score_action_key]))) {
    stop("The ActionLog scoring key must be unique before scoring.", call. = FALSE)
  }

  action_factors <- .normalize_action_factors(lActionFactors)
  observed_states <- unique(stats::na.omit(dfActionLog$State))
  states_without_factors <- setdiff(observed_states, names(action_factors))
  if (length(states_without_factors) > 0L) {
    stop(
      "ActionLog state(s) have no configured action factor: ",
      paste(states_without_factors, collapse = ", "),
      call. = FALSE
    )
  }

  dfWeighted <- JoinRiskScoreWeights(dfResults, dfWeights, strMetricID)
  rows_before_join <- nrow(dfWeighted)
  dfEffective <- dfWeighted %>%
    dplyr::left_join(
      dfActionLog %>%
        dplyr::select(
          dplyr::all_of(.risk_score_action_key),
          ActionState = "State"
        ),
      by = .risk_score_action_key
    )
  if (nrow(dfEffective) != rows_before_join) {
    stop( # nocov start
      "ActionLog join changed the number of KRI result rows.",
      call. = FALSE
    ) # nocov end
  }

  needs_state <- dfEffective$Weight != 0 & is.na(dfEffective$ActionState)
  if (strMissingState == "error" && any(needs_state)) {
    stop(
      "ActionLog state is missing for one or more nonzero KRI weights.",
      call. = FALSE
    )
  }

  configured_factor <- unname(action_factors[dfEffective$ActionState])
  dfEffective$ActionFactor <- dplyr::case_when(
    dfEffective$Weight == 0 ~ 0,
    !is.na(dfEffective$ActionState) ~ configured_factor,
    strMissingState == "include" ~ 1,
    strMissingState == "exclude" ~ 0
  )
  dfEffective$EffectiveWeight <-
    dfEffective$Weight * dfEffective$ActionFactor

  SummarizeRiskScore(dfEffective, "EffectiveWeight", strMetricID)
}