#' Calculate an action-status-weighted Site Risk Score
#'
#' Applies Central Monitoring ActionLog states to existing KRI flag weights.
#' Action factors affect only numerator contributions; the denominator remains
#' the full maximum-risk denominator used by [CalculateRiskScore()]. The
#' per-KRI contributions behind the score are available from
#' [MakeActionRiskScoreDetail()].
#'
#' @param dfResults Current persisted KRI result rows. Must contain one
#'   `StudyID` and one `SnapshotDate` plus `GroupLevel`, `GroupID`, `MetricID`,
#'   and `Flag`.
#' @param dfWeights Risk score weights with `MetricID`, `Flag`, `Weight`, and
#'   `WeightMax`.
#' @param dfActionLog ActionLog rows with the five-column result key, `State`,
#'   and `ExtractionDate`, for the same `StudyID` as `dfResults`. It may hold
#'   several entries per group and metric at different `SnapshotDate`s; for
#'   each group and metric the latest signal snapshot on or before
#'   `dActionSnapshotDate` is used within the selected frozen extraction.
#'   Multiple actions and signals at that snapshot are reduced using the
#'   largest configured factor. Identifiers must distinguish those rows.
#' @param lActionFactors Named numeric state-factor mapping. Defaults to include
#'   open, closed, and awaiting-triage findings and exclude no-action findings.
#' @param strMissingState Policy for a missing action state on a nonzero KRI
#'   weight: stop with an error, include the weight, or exclude the weight.
#' @param strMetricID Metric ID assigned to the action-weighted score.
#' @param dActionSnapshotDate `Date` "As of" date for ActionLog entries. `NULL`
#'   (default) uses the `dfResults` `SnapshotDate`. Must not be later than the
#'   `dfResults` `SnapshotDate`.
#' @param dActionExtractionDate `Date` or ISO `YYYY-MM-DD` cutoff for frozen
#'   ActionLog extractions.
#'   `NULL` uses the results snapshot date. The latest complete extraction on
#'   or before this cutoff is selected, without filling gaps from older
#'   extractions. Set an explicit date when replaying a scoring run whose
#'   ActionLog was frozen after the data snapshot. Signal snapshot dates do
#'   not establish when action states became known.
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
  dActionSnapshotDate = NULL,
  dActionExtractionDate = NULL
) {
  dfDetail <- MakeActionRiskScoreDetail(
    dfResults = dfResults,
    dfWeights = dfWeights,
    dfActionLog = dfActionLog,
    lActionFactors = lActionFactors,
    strMissingState = strMissingState,
    strMetricID = strMetricID,
    dActionSnapshotDate = dActionSnapshotDate,
    dActionExtractionDate = dActionExtractionDate
  )

  SummarizeRiskScore(dfDetail, "EffectiveWeight", strMetricID)
}

#' Per-KRI detail behind an action-status-weighted Site Risk Score
#'
#' Returns one row per weighted KRI result with the ActionLog entry applied to
#' it, so a reader can see why an action-weighted score differs from the
#' original Site Risk Score. [CalculateActionRiskScore()] summarizes these rows.
#'
#' @inheritParams CalculateActionRiskScore
#'
#' @return A data frame with one row per `GroupLevel`, `GroupID`, and
#'   `MetricID` and columns `StudyID`, `SnapshotDate`, `GroupLevel`,
#'   `GroupID`, `MetricID`, `Flag`, `Weight`, `WeightMax`, `ActionState`,
#'   `ActionSnapshotDate` (the `SnapshotDate` of the ActionLog entry applied),
#'   `ActionSource` (`"ActionLog"`, `"Missing"`, or `"Zero weight"`),
#'   `ActionFactor`, `EffectiveWeight`, `ActionExtractionDate`, `RiskSignalID`,
#'   `ActionID`, and `ActionCount`. States and identifiers from multiple rows
#'   are sorted and comma-separated; `ActionCount` counts distinct actions.
#' @export
MakeActionRiskScoreDetail <- function(
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
  dActionSnapshotDate = NULL,
  dActionExtractionDate = NULL
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
  if (!is.null(dActionExtractionDate) &&
      is.character(dActionExtractionDate) && length(dActionExtractionDate) == 1L &&
      !is.na(dActionExtractionDate)) {
    parsed_date <- as.Date(dActionExtractionDate, format = "%Y-%m-%d")
    if (!is.na(parsed_date) &&
        identical(format(parsed_date, "%Y-%m-%d"), dActionExtractionDate)) {
      dActionExtractionDate <- parsed_date
    }
  }
  if (!is.null(dActionExtractionDate) &&
      (!inherits(dActionExtractionDate, "Date") ||
        length(dActionExtractionDate) != 1L || is.na(dActionExtractionDate))) {
    stop("dActionExtractionDate must be NULL or a single non-missing Date.", call. = FALSE)
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
  identity_columns <- c(
    .risk_score_action_key, "ExtractionDate",
    intersect(c("RiskSignalID", "ActionID"), names(dfActionLog))
  )
  if (any(duplicated(dfActionLog[, identity_columns]))) {
    stop("The ActionLog scoring key must be unique before scoring.", call. = FALSE)
  }

  as_of <- if (is.null(dActionSnapshotDate)) {
    result_context$SnapshotDate
  } else {
    dActionSnapshotDate
  }
  if (as_of > result_context$SnapshotDate) {
    stop(
      "dActionSnapshotDate must not be later than the dfResults SnapshotDate.",
      call. = FALSE
    )
  }
  extraction_cutoff <- if (is.null(dActionExtractionDate)) {
    result_context$SnapshotDate
  } else {
    dActionExtractionDate
  }
  dfActionCurrent <- dfActionLog[
    dfActionLog$ExtractionDate <= extraction_cutoff, , drop = FALSE
  ]
  if (nrow(dfActionCurrent) > 0L) {
    dfActionCurrent <- dfActionCurrent[
      dfActionCurrent$ExtractionDate == max(dfActionCurrent$ExtractionDate), ,
      drop = FALSE
    ]
  }
  dfActionCurrent <- dfActionCurrent[
    dfActionCurrent$SnapshotDate <= as_of, , drop = FALSE
  ] %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(.risk_score_action_join_key))) %>%
    dplyr::slice_max(.data$SnapshotDate, n = 1L, with_ties = TRUE) %>%
    dplyr::ungroup()

  action_factors <- .normalize_action_factors(lActionFactors)
  observed_states <- unique(stats::na.omit(dfActionCurrent$State))
  states_without_factors <- setdiff(observed_states, names(action_factors))
  if (length(states_without_factors) > 0L) {
    stop(
      "ActionLog state(s) have no configured action factor: ",
      paste(states_without_factors, collapse = ", "),
      call. = FALSE
    )
  }
  for (column in c("RiskSignalID", "ActionID")) {
    if (!column %in% names(dfActionCurrent)) {
      dfActionCurrent[[column]] <- rep(NA_character_, nrow(dfActionCurrent))
    }
  }
  dfActionCurrent$ActionFactor <- unname(action_factors[dfActionCurrent$State])
  dfActionCurrent$ActionFactor[is.na(dfActionCurrent$ActionFactor)] <-
    if (strMissingState == "exclude") 0 else 1
  dfActionCurrent <- dfActionCurrent %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(.risk_score_action_join_key))) %>%
    dplyr::summarize(
      ActionState = .collapse_action_values(.data$State),
      ActionSnapshotDate = .data$SnapshotDate[1L],
      ActionExtractionDate = .data$ExtractionDate[1L],
      RiskSignalID = .collapse_action_values(.data$RiskSignalID),
      ActionCount = dplyr::n_distinct(.data$ActionID, na.rm = TRUE),
      ActionID = .collapse_action_values(.data$ActionID),
      ActionFactor = max(c(0, .data$ActionFactor)),
      ActionStateMissing = anyNA(.data$State),
      .groups = "drop"
    )

  dfWeighted <- JoinRiskScoreWeights(dfResults, dfWeights, strMetricID)
  rows_before_join <- nrow(dfWeighted)
  dfEffective <- dfWeighted %>%
    dplyr::left_join(
      dfActionCurrent,
      by = .risk_score_action_join_key
    )
  if (nrow(dfEffective) != rows_before_join) {
    stop( # nocov start
      "ActionLog join changed the number of KRI result rows.",
      call. = FALSE
    ) # nocov end
  }

  needs_state <- dfEffective$Weight != 0 &
    (is.na(dfEffective$ActionState) |
      dplyr::coalesce(dfEffective$ActionStateMissing, FALSE))
  if (strMissingState == "error" && any(needs_state)) {
    stop(
      "ActionLog state is missing for one or more nonzero KRI weights.",
      call. = FALSE
    )
  }

  dfEffective$ActionFactor <- dplyr::case_when(
    dfEffective$Weight == 0 ~ 0,
    !is.na(dfEffective$ActionFactor) ~ dfEffective$ActionFactor,
    strMissingState == "include" ~ 1,
    strMissingState == "exclude" ~ 0
  )
  dfEffective$ActionSource <- dplyr::case_when(
    dfEffective$Weight == 0 ~ "Zero weight",
    !is.na(dfEffective$ActionState) ~ "ActionLog",
    TRUE ~ "Missing"
  )
  dfEffective$EffectiveWeight <-
    dfEffective$Weight * dfEffective$ActionFactor

  dfEffective %>%
    dplyr::select(
      "StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID",
      "Flag", "Weight", "WeightMax", "ActionState", "ActionSnapshotDate",
      "ActionSource", "ActionFactor", "EffectiveWeight", "ActionExtractionDate",
      "RiskSignalID", "ActionID", "ActionCount"
    )
}

.collapse_action_values <- function(values) {
  values <- sort(unique(as.character(values[!is.na(values)])))
  if (length(values) == 0L) NA_character_ else paste(values, collapse = ", ")
}
