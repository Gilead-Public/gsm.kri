#' Visualize Risk Score
#'
#' Creates an interactive risk score widget for cross-study visualization.
#'
#' For a working example see
#' [Cross-Study KRI Report](https://gilead-public.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
#'
#' @param dfResults `data.frame` Analysis results from CalculateRiskScore
#' @param dfMetrics `data.frame` Metric metadata from gsm.core::reportingMetrics
#' @param dfGroups `data.frame` Group metadata from gsm.core::reportingGroups
#' @param strGroupLevel `character` The group level to filter the risk score
#'   data. Default is 'Site'.
#' @param strRiskScoreMetric `character` Risk score MetricID to display.
#'   Defaults to `"Analysis_srs0001"`.
#'
#' @export

Visualize_RiskScore <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  strRiskScoreMetric = "Analysis_srs0001"
) {
  # For cross-study functionality, use the cross-study widget
  Widget_CrossStudyRiskScore(
    dfResults,
    dfMetrics,
    dfGroups,
    strGroupLevel,
    strRiskScoreMetric
  )
}
