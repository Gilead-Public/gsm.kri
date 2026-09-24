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
#' @param dfActionLog ActionLog rows with the five-column result key, `State`,
#'   and `ExtractionDate`, for the same `StudyID` as `dfResults`. It may span
#'   several `SnapshotDate`s; only the rows at `dActionSnapshotDate` are used,
#'   matched to `dfResults` on `StudyID`, `GroupLevel`, `GroupID`, and
#'   `MetricID`. The five-column key must be unique.
#' @param lActionFactors Named numeric state-factor mapping. Defaults to include
#'   open, closed, and awaiting-triage findings and exclude no-action findings.
#' @param strMissingState Policy for a missing action state on a nonzero KRI
#'   weight: stop with an error, include the weight, or exclude the weight.
#' @param strMetricID Metric ID assigned to the action-weighted score.
#' @param dActionSnapshotDate `Date` ActionLog `SnapshotDate` whose states are
#'   applied. `NULL` (default) uses the latest `SnapshotDate` in `dfActionLog`.
#'   Must not be later than the `dfResults` `SnapshotDate`.
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
  strMetricID = "Analysis_srs0002",
  dActionSnapshotDate = NULL
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

  if (!is.null(dActionSnapshotDate) &&
      (!inherits(dActionSnapshotDate, "Date") ||
        length(dActionSnapshotDate) != 1L || is.na(dActionSnapshotDate))) {
    stop("dActionSnapshotDate must be NULL or a single non-missing Date.", call. = FALSE)
  }
  action_study <- unique(dfActionLog$StudyID[!is.na(dfActionLog$StudyID)])
  if (nrow(dfActionLog) > 0L &&
      !identical(as.character(action_study), as.character(result_context$StudyID))) {
    stop("dfResults and dfActionLog must represent the same StudyID.", call. = FALSE)
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

  # The ActionLog is frozen when a snapshot is generated and can span many
  # SnapshotDates; the latest one holds the current state of every signal.
  if (nrow(dfActionLog) > 0L) {
    action_snapshot_date <- if (is.null(dActionSnapshotDate)) {
      max(dfActionLog$SnapshotDate)
    } else {
      dActionSnapshotDate
    }
    if (!action_snapshot_date %in% dfActionLog$SnapshotDate) {
      stop(
        "dActionSnapshotDate ", format(action_snapshot_date),
        " is not present in dfActionLog.",
        call. = FALSE
      )
    }
    if (action_snapshot_date > result_context$SnapshotDate) {
      stop(
        "The selected ActionLog SnapshotDate must not be later than the dfResults SnapshotDate.",
        call. = FALSE
      )
    }
    dfActionLog <- dfActionLog[
      dfActionLog$SnapshotDate == action_snapshot_date, ,
      drop = FALSE
    ]
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
          dplyr::all_of(.risk_score_action_join_key),
          ActionState = "State"
        ),
      by = .risk_score_action_join_key
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