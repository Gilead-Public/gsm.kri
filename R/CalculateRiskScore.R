#' Calculate Risk Score
#'
#' Calculates the risk score for each group in the provided results data frame.
#' The function aggregates weighted flag values across all metrics for each 
#' group, creating a composite risk score as a percentage of the total possible 
#' risk.
#'
#' @param dfResults `data.frame` Dataframe of stacked analysis outputs from the 
#'   metrics calculated in the `workflow/2_metrics` workflows. Must contain the 
#'   columns `GroupLevel`, `GroupID`, `MetricID`, `Flag`.
#' @param dfWeights `data.frame` Dataframe with Risk score weight information, 
#'   including `MetricID`, `Flag`, `Weight` and `WeightMax`. This data.frame can 
#'   be created by stacking results from `gsm.core::Flag()` for all relevant 
#'   KRIs, or by calling `MakeWeights(gsm.core::reportingMetrics)`.
#' @param strMetricID `character` The MetricID to assign to the calculated risk 
#'   scores. Default is "Analysis_srs0001".
#'
#' @return `data.frame` with risk score data containing columns: `GroupLevel`, 
#'   `GroupID`, `MetricID`, `Numerator` (sum of weights), `Denominator` (sum of 
#'   max weights across all metrics), `Metric` (risk score percentage), `Score` 
#'   (same as Metric), and `Flag` (set to NA).
#'
#' @details
#' The function calculates risk scores by:
#' \enumerate{
#'   \item Summing the `Weight` values for each group across all metrics
#'   \item Calculating a global denominator as the sum of `WeightMax` values across all unique metrics
#'   \item Computing the risk score as (Numerator / Denominator) * 100
#' }
#'
#' Risk scores represent the percentage of total possible risk that each group 
#' exhibits, allowing for comparison across groups and identification of 
#' high-risk sites or entities.
#'
#' @examples
#' # Prepare data with weights from gsm.core::reportingResults
#' library(dplyr)
#'
#' # Filter to single study/snapshot and remove any existing risk scores
#' dfResults <- gsm.core::reportingResults %>%
#'   dplyr::filter(!grepl("srs0001", MetricID)) %>%
#'   FilterByLatestSnapshotDate()
#'
#' # Create weights table
#' dfWeights <- MakeWeights(gsm.core::reportingMetrics)
#'
#' # Calculate risk scores
#' dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)
#'
#' @export

CalculateRiskScore <- function(
  dfResults,
  dfWeights,
  strMetricID = "Analysis_srs0001"
) {
  # Check that required columns for dfResults are present
  required_cols <- c("GroupLevel", "GroupID", "MetricID", "Flag")
  if (!all(required_cols %in% colnames(dfResults))) {
    missing_cols <- required_cols[!required_cols %in% colnames(dfResults)]
    stop(
      "Missing required columns in dfResults: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Check that MetricID is not present in dfResults$MetricID

  if (strMetricID %in% dfResults$MetricID) {
    stop(paste(
      "MetricID",
      strMetricID,
      "already exists in dfResults. Did you already calculate a site risk score?"
    ))
  }

  # Check that the combination of GroupLevel + GroupID + MetricID is unique
  if (any(duplicated(dfResults[, c("GroupLevel", "GroupID", "MetricID")]))) {
    stop(
      "The combination of 'GroupLevel', 'GroupID', and 'MetricID' must be unique in dfResults. Do you have multiple Snapshots or Studies in your data?"
    )
  }

  # Check that dfWeights is not NULL and that required columns are present
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

  # Check that Weight and WeightMax are numeric
  if (!is.numeric(dfWeights$Weight) || !is.numeric(dfWeights$WeightMax)) {
    stop("Columns 'Weight' and 'WeightMax' must be numeric.")
  }

  # Check that the combination of MetricID and Flag is unique
  if (any(duplicated(dfWeights[, c("MetricID", "Flag")]))) {
    stop(
      "The combination of 'MetricID' and 'Flag' must be unique in dfWeights."
    )
  }

  # Combine dfResults and dfWeights
  dfResults <- dfResults %>%
    left_join(dfWeights, by = c("MetricID", "Flag"))

  # Drop row that have NA values of Weight or WeightMax and throw a warning
  if (any(is.na(dfResults$Weight)) || any(is.na(dfResults$WeightMax))) {
    strMetricIDs <- unique(dfResults$MetricID)
    dfResults <- dfResults %>%
      filter(!is.na(.data$Weight) & !is.na(.data$WeightMax))
    strMetricIDsWithoutWeights <- setdiff(
      strMetricIDs,
      unique(dfResults$MetricID)
    )
    warning(glue::glue(
      "Rows with NA values in 'Weight' or 'WeightMax' have been dropped, corresponding to the",
      "following metric IDs:\n- {paste(strMetricIDsWithoutWeights, collapse = '\n- ')}."
    ))
  }

  # Check that WeightMax is the same within each MetricID
  dfMaxWeights <- dfResults %>%
    group_by(.data$MetricID) %>%
    summarize(
      distinct = n_distinct(.data$WeightMax),
      min_WeightMax = min(.data$WeightMax),
      max_WeightMax = max(.data$WeightMax)
    ) %>%
    ungroup()

  if (any(dfMaxWeights$distinct > 1)) {
    stop("'WeightMax' should be the same for each 'MetricID'.")
  }

  # calculate global denominator
  GlobalDenominator <- sum(dfMaxWeights$max_WeightMax)

  dfRiskScore <- dfResults %>%
    group_by(
      .data$GroupLevel,
      .data$GroupID
    ) %>%
    summarize(
      MetricID = strMetricID,
      Numerator = sum(.data$Weight, na.rm = TRUE),
      Denominator = GlobalDenominator,
      Metric = .data$Numerator / .data$Denominator * 100,
      Score = .data$Metric,
      .groups = "drop"
    ) %>%
    mutate(
      Flag = NA
    )

  return(dfRiskScore)
}
