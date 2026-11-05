#' Summarize dated monitoring decisions across KRI signal snapshots
#'
#' Returns one row per current site/KRI, independently of risk score weights.
#' Only explicit `ActionedDate` values with a populated `ActionedDateSource`
#' establish action recency. Signal creation, resolution, and extraction dates
#' are never substituted. The latest complete extraction is selected first.
#'
#' @inheritParams CalculateActionRiskScore
#' @param intActionWindowDays Nonnegative integer action window, inclusive at
#'   both ends. Default: 90 days.
#' @param dActionAsOfDate Date or ISO date for assessing action age. Defaults
#'   to the results snapshot. May be later for a subsequent monitoring review.
#' @param bActionHistoryComplete Whether the selected extraction contains the
#'   complete decision history. Default: FALSE. Incomplete history cannot
#'   establish that a KRI was never addressed or justify score exclusion.
#'
#' @details
#' Enrich the source-neutral ActionLog with authoritative `ActionedDate`
#' (Date), `ActionedDateSource` (character), `ActionedFlag` (the numeric flag
#' reviewed), and `ActionScope` (`"SiteMetric"` or `"Signal"`). These additive
#' fields describe documented monitoring decisions, not inferred work-item
#' activity. A dated No Action decision may qualify; automatic creation does
#' not. Missing event data remain unknown.
#'
#' A SiteMetric decision can cover repeated signals across snapshots; a Signal
#' decision covers only its own snapshot. Increased severity, changed flag
#' direction, mismatched optional `RiskEpisodeID`, any explicit `ActionReopened`,
#' critical actions, or undated decisions prevent exclusion. When episode
#' identity is unavailable, SiteMetric scope must explicitly mean that the
#' decision applies to the ongoing site/KRI finding.
#' Conflicting latest-day severity, scope, or episode evidence also prevents
#' exclusion; deterministic ID ordering selects a representative audit row only.
#' Existing ActionLogs without these additive event fields remain supported,
#' but do not establish an action date. The extractor must obtain authoritative
#' decision dates and evidence from its source system; a current-state read
#' alone is not a decision history.
#'
#' @return Current KRI keys and flags, last known action date, age, recency,
#'   source identifiers, coverage evidence, `RecentlyAddressed`, and an
#'   `ActionReason`. `ActionRecency` is Recent, Expired, Never, or Unknown.
#'   Never requires complete history; undated evidence remains Unknown.
#'   Dates older than the window are retained. The summary is independent of
#'   weights and does not change the original KRI results or risk score.
#' @examples
#' results <- data.frame(
#'   StudyID = "Study-1", SnapshotDate = as.Date("2026-11-04"),
#'   GroupLevel = "Site", GroupID = c("1001", "1002"),
#'   MetricID = "Analysis_kri0001", Flag = 2
#' )
#' actions <- results[1, ]
#' actions$SnapshotDate <- as.Date("2026-10-01")
#' actions$ExtractionDate <- as.Date("2026-11-04")
#' actions$State <- "Closed Action"
#' actions$RiskSignalID <- "RS-1"
#' actions$ActionID <- "ACT-1"
#' actions$ActionedDate <- as.Date("2026-10-15")
#' actions$ActionedDateSource <- "Monitoring decision"
#' actions$ActionedFlag <- 2
#' actions$ActionScope <- "SiteMetric"
#' MakeActionSummary(results, actions, bActionHistoryComplete = TRUE)
#' @export
MakeActionSummary <- function(
  dfResults,
  dfActionLog,
  intActionWindowDays = 90L,
  dActionAsOfDate = NULL,
  dActionExtractionDate = NULL,
  bActionHistoryComplete = FALSE
) {
  context <- .validate_single_study_snapshot(dfResults, "dfResults")
  if (!is.numeric(intActionWindowDays) || length(intActionWindowDays) != 1L ||
      is.na(intActionWindowDays) || !is.finite(intActionWindowDays) ||
      intActionWindowDays < 0 || intActionWindowDays != floor(intActionWindowDays)) {
    stop("intActionWindowDays must be a nonnegative integer.", call. = FALSE)
  }
  if (!is.logical(bActionHistoryComplete) || length(bActionHistoryComplete) != 1L ||
      is.na(bActionHistoryComplete)) {
    stop("bActionHistoryComplete must be TRUE or FALSE.", call. = FALSE)
  }
  required_results <- c(.risk_score_action_key, "Flag")
  required_actions <- c(.risk_score_action_key, "State", "ExtractionDate")
  if (!all(required_results %in% names(dfResults)) ||
      !is.data.frame(dfActionLog) || !all(required_actions %in% names(dfActionLog))) {
    stop("Results and ActionLog must contain their KRI keys, Flag, State, and ExtractionDate.", call. = FALSE)
  }
  if (!inherits(dfResults$SnapshotDate, "Date") ||
      !inherits(dfActionLog$SnapshotDate, "Date") ||
      !inherits(dfActionLog$ExtractionDate, "Date") ||
      anyNA(dfActionLog$ExtractionDate) ||
      any(!stats::complete.cases(dfResults[, .risk_score_action_key])) ||
      any(!stats::complete.cases(dfActionLog[, .risk_score_action_key]))) {
    stop("KRI keys must be complete and snapshot/extraction columns must use Date.", call. = FALSE)
  }
  if (!is.numeric(dfResults$Flag) ||
      any(duplicated(dfResults[, .risk_score_action_key]))) {
    stop("Current KRI keys must be unique and Flag must be numeric.", call. = FALSE)
  }
  if (any(dfActionLog$StudyID != context$StudyID) ||
      any(dfActionLog$ExtractionDate < dfActionLog$SnapshotDate)) {
    stop("ActionLog must match the study and extraction must not predate the signal.", call. = FALSE)
  }
  identity <- c(required_actions, intersect(c("RiskSignalID", "ActionID", "ActionEventID"), names(dfActionLog)))
  identity <- setdiff(identity, "State")
  if (any(duplicated(dfActionLog[, identity]))) {
    stop("The ActionLog scoring key must be unique before summarizing.", call. = FALSE)
  }
  as_of <- .action_summary_date(dActionAsOfDate, context$SnapshotDate, "dActionAsOfDate")
  extraction_cutoff <- .action_summary_date(dActionExtractionDate, as_of, "dActionExtractionDate")
  actions <- dfActionLog[dfActionLog$ExtractionDate <= extraction_cutoff, , drop = FALSE]
  extraction_date <- as.Date(NA)
  if (nrow(actions) > 0L) {
    extraction_date <- max(actions$ExtractionDate)
    actions <- actions[actions$ExtractionDate == extraction_date &
      actions$SnapshotDate <= min(context$SnapshotDate, as_of), , drop = FALSE]
  }
  defaults <- list(
    RiskSignalID = NA_character_, ActionID = NA_character_,
    ActionedDate = as.Date(NA), ActionedDateSource = NA_character_,
    ActionedFlag = NA_real_, ActionScope = NA_character_,
    RiskEpisodeID = NA_character_, ActionReopened = FALSE,
    ActionCriticality = FALSE
  )
  for (column in names(defaults)) {
    if (!column %in% names(actions)) actions[[column]] <- rep(defaults[[column]], nrow(actions))
  }
  if (!inherits(actions$ActionedDate, "Date") || !is.numeric(actions$ActionedFlag) ||
      !is.logical(actions$ActionReopened) || !is.logical(actions$ActionCriticality)) {
    stop("ActionedDate must use Date; ActionedFlag must be numeric; action indicators must be logical.", call. = FALSE)
  }
  if (any(actions$ActionedDate > actions$ExtractionDate, na.rm = TRUE) ||
      any(actions$ActionedDate < actions$SnapshotDate, na.rm = TRUE)) {
    stop("ActionedDate must be between its signal snapshot and extraction date.", call. = FALSE)
  }
  actions <- actions[
    is.na(actions$ActionedDate) | actions$ActionedDate <= as_of, , drop = FALSE
  ]
  actions$HasDatedDecision <- !is.na(actions$ActionedDate) &
    !is.na(actions$ActionedDateSource) & nzchar(trimws(actions$ActionedDateSource)) &
    actions$State %in% c("Open Action", "Closed Action", "No Action")
  information <- actions %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(.risk_score_action_join_key))) %>%
    dplyr::summarize(
      ActionCount = dplyr::n_distinct(.data$ActionID, na.rm = TRUE),
      HasUndatedDecision = any(!.data$HasDatedDecision &
        .data$State %in% c("Open Action", "Closed Action", "No Action")),
      HasReopenedAction = any(.data$ActionReopened %in% TRUE),
      HasCriticalAction = any(.data$ActionCriticality %in% TRUE),
      .groups = "drop"
    )
  decisions <- actions %>%
    dplyr::filter(.data$HasDatedDecision, .data$ActionedDate <= as_of) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(.risk_score_action_join_key))) %>%
    dplyr::slice_max(.data$ActionedDate, n = 1L, with_ties = TRUE) %>%
    dplyr::mutate(
      HasConflictingLatestDecision = dplyr::n_distinct(
        .data$ActionedFlag, .data$ActionScope, .data$RiskEpisodeID,
        dplyr::if_else(.data$ActionScope == "Signal", as.character(.data$SnapshotDate), NA_character_)
      ) > 1L
    ) %>%
    dplyr::arrange(.data$RiskSignalID, .data$ActionID, .by_group = TRUE) %>%
    dplyr::slice_head(n = 1L) %>%
    dplyr::ungroup() %>%
    dplyr::select(
      dplyr::all_of(.risk_score_action_join_key),
      "HasConflictingLatestDecision",
      LastActionedDate = "ActionedDate", ActionedDateSource = "ActionedDateSource",
      ActionedFlag = "ActionedFlag", ActionScope = "ActionScope",
      ActionSignalSnapshotDate = "SnapshotDate", ActionState = "State",
      ActionRiskSignalID = "RiskSignalID", ActionID = "ActionID",
      ActionRiskEpisodeID = "RiskEpisodeID"
    )
  summary <- dfResults[, required_results, drop = FALSE]
  summary$RiskEpisodeID <- if ("RiskEpisodeID" %in% names(dfResults)) {
    as.character(dfResults$RiskEpisodeID)
  } else {
    NA_character_
  }
  summary <- summary %>%
    dplyr::left_join(information, by = .risk_score_action_join_key) %>%
    dplyr::left_join(decisions, by = .risk_score_action_join_key) %>%
    dplyr::mutate(
      ActionExtractionDate = extraction_date,
      ActionAsOfDate = as_of,
      ActionWindowDays = intActionWindowDays,
      ActionHistoryComplete = bActionHistoryComplete & !is.na(extraction_date),
      ActionCount = dplyr::coalesce(.data$ActionCount, 0L),
      HasUndatedDecision = dplyr::coalesce(.data$HasUndatedDecision, FALSE),
      HasReopenedAction = dplyr::coalesce(.data$HasReopenedAction, FALSE),
      HasCriticalAction = dplyr::coalesce(.data$HasCriticalAction, FALSE),
      HasConflictingLatestDecision = dplyr::coalesce(.data$HasConflictingLatestDecision, FALSE),
      DaysSinceAction = as.integer(as_of - .data$LastActionedDate),
      ActionRecency = dplyr::case_when(
        !is.na(.data$LastActionedDate) & .data$DaysSinceAction <= intActionWindowDays ~ "Recent",
        !is.na(.data$LastActionedDate) ~ "Expired",
        .data$ActionHistoryComplete & !.data$HasUndatedDecision ~ "Never",
        TRUE ~ "Unknown"
      ),
      ActionCoverageReason = dplyr::case_when(
        is.na(.data$LastActionedDate) ~ "No dated decision",
        !.data$ActionHistoryComplete | .data$HasUndatedDecision ~ "Incomplete action history",
        .data$HasReopenedAction ~ "Reopened finding",
        .data$HasCriticalAction ~ "Critical action",
        .data$HasConflictingLatestDecision ~ "Conflicting latest decisions",
        is.na(.data$ActionedFlag) | is.na(.data$Flag) ~ "Reviewed severity unknown",
        abs(.data$Flag) > abs(.data$ActionedFlag) |
          (.data$Flag != 0 & sign(.data$Flag) != sign(.data$ActionedFlag)) ~ "Changed or increased severity",
        !(is.na(.data$RiskEpisodeID) & is.na(.data$ActionRiskEpisodeID)) &
          (is.na(.data$RiskEpisodeID) | is.na(.data$ActionRiskEpisodeID) |
            .data$RiskEpisodeID != .data$ActionRiskEpisodeID) ~ "Different or unknown risk episode",
        .data$ActionScope == "SiteMetric" ~ "Recently addressed",
        .data$ActionScope == "Signal" &
          .data$ActionSignalSnapshotDate == .data$SnapshotDate ~ "Recently addressed",
        TRUE ~ "Decision coverage unknown"
      ),
      DecisionCoversFinding = .data$ActionCoverageReason == "Recently addressed",
      RecentlyAddressed = .data$ActionRecency == "Recent" & .data$DecisionCoversFinding,
      ActionReason = dplyr::if_else(
        .data$ActionRecency == "Recent", .data$ActionCoverageReason, .data$ActionRecency
      )
    )
  summary
}

.action_summary_date <- function(value, default, label) {
  if (is.null(value)) return(default)
  if (is.character(value) && length(value) == 1L && !is.na(value)) {
    parsed <- as.Date(value, format = "%Y-%m-%d")
    if (!is.na(parsed) && identical(format(parsed, "%Y-%m-%d"), value)) value <- parsed
  }
  if (!inherits(value, "Date") || length(value) != 1L || is.na(value)) {
    stop(label, " must be NULL, a Date, or an ISO date.", call. = FALSE)
  }
  value
}