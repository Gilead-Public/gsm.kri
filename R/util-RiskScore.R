.risk_score_result_key <- c("GroupLevel", "GroupID", "MetricID")

.risk_score_action_key <- c(
  "StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID"
)

.risk_score_action_states <- c(
  "Open Action", "Closed Action", "Awaiting Triage", "No Action"
)

JoinRiskScoreWeights <- function(dfResults, dfWeights, strMetricID) {
  required_cols <- c("GroupLevel", "GroupID", "MetricID", "Flag")
  if (!all(required_cols %in% colnames(dfResults))) {
    missing_cols <- required_cols[!required_cols %in% colnames(dfResults)]
    stop(
      "Missing required columns in dfResults: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  if (strMetricID %in% dfResults$MetricID) {
    stop(paste(
      "MetricID",
      strMetricID,
      "already exists in dfResults. Did you already calculate a site risk score?"
    ))
  }

  if (any(duplicated(dfResults[, .risk_score_result_key]))) {
    stop(
      "The combination of 'GroupLevel', 'GroupID', and 'MetricID' must be unique in dfResults. Do you have multiple Snapshots or Studies in your data?"
    )
  }

  if (is.null(dfWeights)) {
    stop("dfWeights is NULL. Please provide a valid dfWeights data frame.")
  }

  required_cols_weights <- c("MetricID", "Flag", "Weight", "WeightMax")
  if (!all(required_cols_weights %in% colnames(dfWeights))) {
    missing_cols <- required_cols_weights[
      !required_cols_weights %in% colnames(dfWeights)
    ]
    stop(
      "Missing required columns in dfWeights: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  if (!is.numeric(dfWeights$Weight) || !is.numeric(dfWeights$WeightMax)) {
    stop("Columns 'Weight' and 'WeightMax' must be numeric.")
  }

  if (any(duplicated(dfWeights[, c("MetricID", "Flag")]))) {
    stop(
      "The combination of 'MetricID' and 'Flag' must be unique in dfWeights."
    )
  }

  dfWeighted <- dfResults %>%
    dplyr::left_join(dfWeights, by = c("MetricID", "Flag"))

  if (any(is.na(dfWeighted$Weight)) || any(is.na(dfWeighted$WeightMax))) {
    strMetricIDs <- unique(dfWeighted$MetricID)
    dfWeighted <- dfWeighted %>%
      dplyr::filter(!is.na(.data$Weight) & !is.na(.data$WeightMax))
    strMetricIDsWithoutWeights <- setdiff(
      strMetricIDs,
      unique(dfWeighted$MetricID)
    )
    warning(glue::glue(
      "Rows with NA values in 'Weight' or 'WeightMax' have been dropped, corresponding to the",
      "following metric IDs:\n- {paste(strMetricIDsWithoutWeights, collapse = '\n- ')}."
    ))
  }

  dfWeighted
}

SummarizeRiskScore <- function(
  dfWeighted,
  strWeightColumn = "Weight",
  strMetricID = "Analysis_srs0001"
) {
  if (!strWeightColumn %in% names(dfWeighted) ||
      !is.numeric(dfWeighted[[strWeightColumn]])) {
    stop("The selected risk score weight column must exist and be numeric.")
  }

  dfMaxWeights <- dfWeighted %>%
    dplyr::group_by(.data$MetricID) %>%
    dplyr::summarize(
      distinct = dplyr::n_distinct(.data$WeightMax),
      min_WeightMax = min(.data$WeightMax),
      max_WeightMax = max(.data$WeightMax),
      .groups = "drop"
    )

  if (any(dfMaxWeights$distinct > 1)) {
    stop("'WeightMax' should be the same for each 'MetricID'.")
  }

  GlobalDenominator <- sum(dfMaxWeights$max_WeightMax)

  dfWeighted %>%
    dplyr::group_by(.data$GroupLevel, .data$GroupID) %>%
    dplyr::summarize(
      MetricID = strMetricID,
      Numerator = sum(.data[[strWeightColumn]], na.rm = TRUE),
      Denominator = GlobalDenominator,
      Metric = .data$Numerator / .data$Denominator * 100,
      Score = .data$Metric,
      .groups = "drop"
    ) %>%
    dplyr::mutate(Flag = NA)
}

.validate_single_study_snapshot <- function(data, label, allow_empty = FALSE) {
  missing <- setdiff(c("StudyID", "SnapshotDate"), names(data))
  if (length(missing) > 0) {
    stop(
      label,
      " is missing required temporal columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (nrow(data) == 0L && allow_empty) {
    return(invisible(NULL))
  }
  study_ids <- unique(data$StudyID[!is.na(data$StudyID)])
  snapshot_dates <- unique(as.Date(data$SnapshotDate[!is.na(data$SnapshotDate)]))
  if (length(study_ids) != 1L || length(snapshot_dates) != 1L) {
    stop(
      label,
      " must contain exactly one non-missing StudyID and SnapshotDate.",
      call. = FALSE
    )
  }
  list(StudyID = study_ids, SnapshotDate = snapshot_dates)
}

.normalize_action_factors <- function(lActionFactors) {
  factors <- unlist(lActionFactors, use.names = TRUE)
  if (!is.numeric(factors) || is.null(names(factors)) ||
      anyNA(factors) || any(!is.finite(factors)) ||
      any(factors < 0 | factors > 1) ||
      any(names(factors) == "") || anyDuplicated(names(factors))) {
    stop(
      "lActionFactors must be a uniquely named numeric mapping with values between 0 and 1.",
      call. = FALSE
    )
  }
  factors
}