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
#'   Default: `"Review Priority Score"` for dated action detail, otherwise
#'   `"Adjusted Risk Score"`. An explicit label is always preserved.
#' @param strGroupSubset Optional group subset passed to the report's group
#'   overview. `NULL` preserves the report default (`"red"` for site reports,
#'   `"all"` otherwise).
#' @param dfRiskScoreDetail Optional per-KRI detail behind the second risk
#'   score, from [MakeActionRiskScoreDetail()]. Clicking a score in that column
#'   lists each KRI's action evidence and whether it counts toward the score.
#'   Dated detail adds a border to each site/KRI cell with a recorded action
#'   within 90 days, without changing scores or flag colors. Ignored when the
#'   comparison metric is absent from `dfResults`. Default: `NULL`.
#' @param lData Optional workflow domain list. Used to obtain
#'   `Analysis_ActionRiskScoreDetail` when `dfRiskScoreDetail` is NULL.
#' @details Character ISO snapshot dates and identifiers are normalized at the
#'   report boundary. An absent comparison metric leaves the original report
#'   layout unchanged. Empty optional detail is treated as NULL; a present score
#'   without detail warns and renders without its drilldown. Invalid supplied
#'   detail or mismatched current group keys is an error.
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
  strComparisonRiskLabel = "Adjusted Risk Score",
  strGroupSubset = NULL,
  dfRiskScoreDetail = NULL,
  lData = NULL
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_KRI()`")
  rlang::check_installed("knitr", reason = "to run `Report_KRI()`")
  if (!is.null(lData) && !is.list(lData)) {
    cli::cli_abort("{.arg lData} must be NULL or a workflow domain list.")
  }
  if (is.null(dfRiskScoreDetail) && !is.null(lData)) {
    dfRiskScoreDetail <- lData[["Analysis_ActionRiskScoreDetail"]]
  }
  dfResults <- .normalize_risk_report_input(dfResults)
  if (is.data.frame(dfRiskScoreDetail) && nrow(dfRiskScoreDetail) == 0L) dfRiskScoreDetail <- NULL
  if (is.null(strComparisonRiskMetric)) dfRiskScoreDetail <- NULL
  if (is.data.frame(dfResults) && !is.null(strComparisonRiskMetric) &&
    any(dfResults$MetricID %in% strComparisonRiskMetric)) {
    if (is.null(dfRiskScoreDetail)) {
      cli::cli_warn("Comparison score supplied without optional detail; the report will omit the drilldown.")
    } else {
      required <- c("GroupID", "MetricID", "Weight", "EffectiveWeight", "ActionState")
      if (!is.data.frame(dfRiskScoreDetail) || !all(required %in% names(dfRiskScoreDetail))) {
        cli::cli_abort("Comparison detail must contain GroupID, MetricID, Weight, EffectiveWeight, and ActionState.")
      }
      dfRiskScoreDetail <- .normalize_risk_report_input(dfRiskScoreDetail)
      keys <- intersect(c("StudyID", "SnapshotDate", "GroupLevel", "GroupID"),
        intersect(names(dfResults), names(dfRiskScoreDetail)))
      scores <- dfResults[dfResults$MetricID %in% strComparisonRiskMetric, , drop = FALSE]
      if ("SnapshotDate" %in% names(scores) && nrow(scores))
        scores <- scores[scores$SnapshotDate == max(scores$SnapshotDate), , drop = FALSE]
      unmatched <- dplyr::anti_join(unique(scores[keys]), unique(dfRiskScoreDetail[keys]), by = keys)
      if (nrow(unmatched)) cli::cli_abort("Comparison scores have no matching detail for their current study/snapshot/group keys.")
    }
  }
  if (missing(strComparisonRiskLabel) && is.data.frame(dfRiskScoreDetail) &&
      "ActionWindowDays" %in% names(dfRiskScoreDetail)) {
    strComparisonRiskLabel <- if ("ActionPolicy" %in% names(dfRiskScoreDetail) &&
      all(dfRiskScoreDetail$ActionPolicy %in% "disposition")) "Adjusted Risk Score" else "Review Priority Score"
  }
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
  if (!is.null(strGroupSubset) &&
      (!rlang::is_string(strGroupSubset) ||
        !strGroupSubset %in% c("all", "red", "red/amber", "amber"))) {
    cli::cli_abort(
      "{.arg strGroupSubset} must be NULL or one of {.or {c('all', 'red', 'red/amber', 'amber')}}."
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
      strComparisonRiskLabel = strComparisonRiskLabel,
      strGroupSubset = strGroupSubset,
      dfRiskScoreDetail = dfRiskScoreDetail
    )
  )
}

.normalize_risk_report_input <- function(data) {
  if (!is.data.frame(data)) return(data)
  for (column in intersect(c("StudyID", "GroupLevel", "GroupID", "MetricID"), names(data)))
    data[[column]] <- as.character(data[[column]])
  for (column in intersect(c("SnapshotDate", "ActionAsOfDate", "LastActionedDate", "ActionExtractionDate"), names(data))) {
    value <- data[[column]]
    if (inherits(value, "Date")) next
    if (inherits(value, "POSIXt")) {
      data[[column]] <- as.Date(value, tz = "UTC")
    } else if (is.character(value) || is.factor(value)) {
      text <- as.character(value)
      date <- suppressWarnings(as.Date(text, format = "%Y-%m-%d"))
      invalid <- !is.na(text) & (is.na(date) | !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", text) |
        format(date, "%Y-%m-%d") != text)
      if (any(invalid)) stop(paste0(column, " must contain valid ISO dates."), call. = FALSE)
      data[[column]] <- date
    } else {
      stop(paste0(column, " must use Date, POSIXt, or ISO date strings."), call. = FALSE)
    }
  }
  if ("Flag" %in% names(data) && !is.numeric(data$Flag)) {
    value <- data$Flag
    flag <- suppressWarnings(as.numeric(if (is.factor(value)) as.character(value) else value))
    if (any(!is.na(value) & is.na(flag))) stop("Flag must be numeric.", call. = FALSE)
    data$Flag <- flag
  }
  data
}
