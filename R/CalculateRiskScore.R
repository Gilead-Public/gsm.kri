#' Calculate Risk Score
#'
#' Calculates the risk score for each group in the provided results data frame.
#' The function aggregates weighted flag values across all metrics for each group,
#' creating a composite risk score as a percentage of the total possible risk.
#'
#' @param dfResults `data.frame` Dataframe of stacked analysis outputs from the metrics calculated in the
#' `workflow/2_metrics` workflows. Must contain the columns `GroupLevel`, `GroupID`, `MetricID`, `Flag`.
#' @param dfWeights `data.frame` Dataframe with Risk score weight information, including `MetricID`, `Flag`, `Weight` and `WeightMax`. This data.frame can be created by stacking results from `gsm.core::Flag()` for all relevant KRIs, or by calling `gsm.kri::MakeWeights(gsm.core::reportingMetrics)`
#' @param strMetricID `character` The MetricID to assign to the calculated risk scores. Default is "Analysis_srs0001".
#'
#' @return `data.frame` with risk score data containing columns: `GroupLevel`, `GroupID`, `MetricID`,
#' `Numerator` (sum of weights), `Denominator` (sum of max weights across all metrics),
#' `Metric` (risk score percentage), `Score` (same as Metric), and `Flag` (set to NA).
#'
#' @details
#' The function calculates risk scores by:
#' \enumerate{
#'   \item Summing the `Weight` values for each group across all metrics
#'   \item Calculating a global denominator as the sum of `WeightMax` values across all unique metrics
#'   \item Computing the risk score as (Numerator / Denominator) * 100
#' }
#'
#' Risk scores represent the percentage of total possible risk that each group exhibits,
#' allowing for comparison across groups and identification of high-risk sites or entities.
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
#' dfWeights <- gsm.kri::MakeWeights(gsm.core::reportingMetrics)
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
  dfWeighted <- JoinRiskScoreWeights(dfResults, dfWeights, strMetricID)
  SummarizeRiskScore(dfWeighted, "Weight", strMetricID)
}
