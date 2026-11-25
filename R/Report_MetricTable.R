#' Generate a summary table for a report
#'
#' @description `r lifecycle::badge("stable")`
#'
#' This function generates a summary table for a report by joining the provided
#' results data frame with the site-level metadata from dfGroups. It then
#' filters and arranges the data based on certain conditions and displays the
#' result in a datatable.
#'
#' @inheritParams shared-params
#' @param dfResults `r gloss_param("dfResults")` `r gloss_extra("dfResults_filtered")`
#' @param strGroupLevel  group level for the table
#' @param strGroupDetailsParams one or more parameters from dfGroups to be added
#'   as columns in the table
#' @param vFlags `integer` List of flag values to include in output table.
#'   Default: `c(-2, -1, 1, 2)`.
#'
#' @return A [gt::gt()] containing the summary table.
#'
#' @examples
#' # site-level report
#' Report_MetricTable(
#'   dfResults = gsm.core::reportingResults %>%
#'     dplyr::filter(.data$MetricID == "Analysis_kri0001") %>%
#'     FilterByLatestSnapshotDate(),
#'   dfGroups = gsm.core::reportingGroups
#' )
#'
#' @export
Report_MetricTable <- function(
  dfResults,
  dfGroups = NULL,
  strGroupLevel = c("Site", "Country", "Study"),
  strGroupDetailsParams = NULL,
  vFlags = c(-2, -1, 1, 2)
) {
  dfRiskSignals <- MakeMetricTable(
    dfResults,
    dfGroups,
    strGroupLevel,
    strGroupDetailsParams,
    vFlags
  )

  if (!nrow(dfRiskSignals)) {
    emptyMessage <- htmltools::tags$p("Nothing flagged for this KRI.")
    strOutputLabel <- paste0(
      fontawesome::fa("table", fill = "#337ab7"),
      "  Metric Table"
    )
    base::attr(emptyMessage, "output_label") <- strOutputLabel
    return(emptyMessage)
  }

  # Check these columns against columns in the output of [ MakeMetricTable ].
  cols_to_hide <- intersect(
    c("StudyID", "GroupID", "MetricID"),
    names(dfRiskSignals)
  )

  if (length(unique(dfRiskSignals$SnapshotDate == 1))) {
    cols_to_hide <- c(cols_to_hide, "SnapshotDate")
  }

  lMetricTable <- dfRiskSignals %>%
    gt_style() %>%
    gt::cols_hide(cols_to_hide) %>%
    fmt_sign(columns = "Flag")

  strOutputLabel <- paste0(
    fontawesome::fa("table", fill = "#337ab7"),
    "  Metric Table"
  )
  base::attr(lMetricTable, "output_label") <- strOutputLabel

  return(lMetricTable)
}
