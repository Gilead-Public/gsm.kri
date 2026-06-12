#' Visualize Risk Score
#'
#' Creates an interactive risk score widget for cross-study visualization.
#'
#' For a working example see
#' [Cross-Study KRI Report](https://gilead-biostats.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
#'
#' @param dfResults `data.frame` Analysis results from CalculateRiskScore
#' @param dfMetrics `data.frame` Metric metadata from gsm.core::reportingMetrics
#' @param dfGroups `data.frame` Group metadata from gsm.core::reportingGroups
#' @param strGroupLevel `character` The group level to filter the risk score
#'   data. Default is 'Site'.
#'
#' @export

Visualize_RiskScore <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site"
) {
  # For cross-study functionality, use the cross-study widget
  Widget_CrossStudyRiskScore(dfResults, dfMetrics, dfGroups, strGroupLevel)
}
