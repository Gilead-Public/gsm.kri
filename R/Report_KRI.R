#' Report_KRI function
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' This function generates a KRI report based on the provided inputs.
#'
#' @inheritParams shared-params
#' @param lCharts A list of charts to include in the report.
#' @param strOutputDir The output directory path for the generated report. If not provided,
#'  the report will be saved in the current working directory.
#' @param strOutputFile The output file name for the generated report. If not provided,
#'  the report will be named based on the study ID, Group Level and Date.
#' @param strInputPath `string` or `fs_path` Path to the template `Rmd` file.
#' @param strComparisonRiskMetric Optional metric ID displayed immediately after
#'   the existing Site Risk Score in the site overview. The column is omitted
#'   when the metric is absent from `dfResults`. Default: `"Analysis_srs0002"`.
#' @param strComparisonRiskLabel Column label for the comparison risk score.
#'   Default: `"Adjusted Risk Score"`.
#'
#' @return File path of the saved report html is returned invisibly. Save to object to view absolute output path.
#' @examples
#' \dontrun{
#' # Run site-level KRI report.
#' lChartsSite <- MakeCharts(
#'   dfResults = gsm.core::reportingResults,
#'   dfMetrics = gsm.core::reportingMetrics,
#'   dfGroups = gsm.core::reportingGroups,
#'   dfBounds = gsm.core::reportingBounds
#' )
#'
#' strOutputFile <- "StandardSiteReport.html"
#' kri_report_path <- Report_KRI(
#'   lCharts = lChartsSite,
#'   dfResults = gsm.core::reportingResults %>%
#'     FilterByLatestSnapshotDate() %>%
#'     gsm.reporting::CalculateChange(
#'       gsm.core::reportingResults
#'     ),
#'   dfMetrics = gsm.core::reportingMetrics,
#'   dfGroups = gsm.core::reportingGroups,
#'   strOutputFile = strOutputFile
#' )
#'
#' # Run country-level KRI report.
#' lChartsCountry <- MakeCharts(
#'   dfResults = gsm.core::reportingResults_country,
#'   dfMetrics = gsm.core::reportingMetrics_country,
#'   dfGroups = gsm.core::reportingGroups_country,
#'   dfBounds = gsm.core::reportingBounds_country
#' )
#'
#' strOutputFile <- "StandardCountryReport.html"
#' kri_report_path <- Report_KRI(
#'   lCharts = lChartsCountry,
#'   dfResults = gsm.core::reportingResults_country %>%
#'     FilterByLatestSnapshotDate() %>%
#'     gsm.reporting::CalculateChange(
#'       gsm.core::reportingResults_country
#'     ),
#'   dfMetrics = gsm.core::reportingMetrics_country,
#'   dfGroups = gsm.core::reportingGroups_country,
#'   strOutputFile = strOutputFile
#' )
#' }
#'
#' @keywords KRI report
#' @export
#'

Report_KRI <- function(
  lCharts = NULL,
  dfResults = NULL,
  dfMetrics = NULL,
  dfGroups = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_KRI.Rmd", package = "gsm.kri"),
  strComparisonRiskMetric = "Analysis_srs0002",
  strComparisonRiskLabel = "Adjusted Risk Score"
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_KRI()`")
  rlang::check_installed("knitr", reason = "to run `Report_KRI()`")
  if (!is.null(strComparisonRiskMetric) &&
    (!rlang::is_string(strComparisonRiskMetric) ||
      !nzchar(strComparisonRiskMetric))) {
    cli::cli_abort(
      "{.arg strComparisonRiskMetric} must be NULL or a single non-missing string."
    )
  }
  if (!rlang::is_string(strComparisonRiskLabel) ||
      !nzchar(strComparisonRiskLabel)) {
    cli::cli_abort(
      "{.arg strComparisonRiskLabel} must be a single non-missing string."
    )
  }

  # set output path
  if (is.null(strOutputFile)) {
    GroupLevel <- unique(dfMetrics$GroupLevel)
    StudyID <- unique(dfResults$StudyID)
    SnapshotDate <- max(unique(dfResults$SnapshotDate))
    if (length(GroupLevel == 1) & length(StudyID) == 1) {
      # remove non alpha-numeric characters from StudyID, GroupLevel and SnapshotDate
      StudyID <- gsub("[^[:alnum:]]", "", StudyID)
      GroupLevel <- gsub("[^[:alnum:]]", "", GroupLevel)
      SnapshotDate <- gsub("[^[:alnum:]]", "", as.character(SnapshotDate))

      strOutputFile <- paste0(
        "kri_report_",
        StudyID,
        "_",
        GroupLevel,
        "_",
        SnapshotDate,
        ".html"
      )
    } else {
      strOutputFile <- "kri_report.html"
    }
  }

  RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      lCharts = lCharts,
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      strComparisonRiskMetric = strComparisonRiskMetric,
      strComparisonRiskLabel = strComparisonRiskLabel
    )
  )
}
