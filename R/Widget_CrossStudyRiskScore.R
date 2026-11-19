#' Cross-Study Risk Score Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A widget that generates an interactive cross-study risk score table.
#' Shows a summary view with click-to-expand details for each site.
#'
#' Two downloads, each as CSV or XLSX, export the current view: the visible
#' sites in their displayed order, with study-filtered badge values.
#' * **Site summary**: one row per site with Site, Studies, Enrolled, Avg SRS
#'   and Max SRS, as in the collapsed view.
#' * **Site/study detail**: one row per site, study and KRI, repeating the
#'   per-study enrollment, flag counts and risk scores, with the KRI's flag,
#'   score, numerator, denominator and metric, plus its action state, last
#'   addressed date, days ago and whether it falls within 90 days when
#'   `dfComparisonRiskDetail` is supplied.
#'
#' Files are generated in the browser; no data is uploaded.
#'
#' For a working example see [Cross-Study KRI Report](https://gilead-public.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
#'
#' @param dfResults `data.frame` Full results data for details.
#' @param dfMetrics `data.frame` Metadata about metrics/KRIs.
#' @param dfGroups `data.frame` Metadata about groups (sites/studies).
#' @param strGroupLevel `character` The group level. Default is 'Site'.
#' @param strRiskScoreMetric `character` Risk score MetricID to display.
#'   Defaults to `"Analysis_srs0001"`.
#' @param strComparisonRiskMetric Optional metric ID displayed immediately
#'   after the risk score in each site's per-study rows, as in the site report.
#'   The column is omitted when the metric is absent from `dfResults` or is
#'   the same as `strRiskScoreMetric`.
#'   Default: `"Analysis_srs0002"`.
#' @param strComparisonRiskLabel Column label for the comparison risk score.
#'   Default: `"Adjusted Risk Score"`.
#' @param dfComparisonRiskDetail Optional per-KRI detail behind the comparison
#'   score, e.g. stacked `Analysis_ActionRiskScoreDetail` outputs of
#'   [Analyze_ActionRiskScore()] with `StudyID`, `GroupID`, `MetricID`,
#'   `ActionState`, `LastActionedDate`, `DaysSinceAction`, and
#'   `ActionWindowDays`. Each study/site/KRI cell with an action recorded
#'   0 through 90 days before its assessment date is highlighted with the same
#'   colors and legend as the site report. Scores and flag colors are never
#'   changed. Ignored when the comparison metric is absent. Default: `NULL`.
#'
#' @return An htmlwidget for cross-study risk score visualization.
#'
#' @export
Widget_CrossStudyRiskScore <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  strRiskScoreMetric = "Analysis_srs0001",
  strComparisonRiskMetric = "Analysis_srs0002",
  strComparisonRiskLabel = "Adjusted Risk Score",
  dfComparisonRiskDetail = NULL
) {
  stopifnot(is.data.frame(dfResults))
  stopifnot(is.data.frame(dfMetrics))
  stopifnot(is.data.frame(dfGroups))
  stopifnot(is.character(strRiskScoreMetric) && length(strRiskScoreMetric) == 1)
  stopifnot(is.null(strComparisonRiskMetric) || rlang::is_string(strComparisonRiskMetric))
  stopifnot(rlang::is_string(strComparisonRiskLabel) && nzchar(strComparisonRiskLabel))
  stopifnot(is.null(dfComparisonRiskDetail) || is.data.frame(dfComparisonRiskDetail))
  if (is.null(strComparisonRiskMetric) ||
      identical(strComparisonRiskMetric, strRiskScoreMetric) ||
      !strComparisonRiskMetric %in% dfResults$MetricID) {
    strComparisonRiskMetric <- NULL
    dfComparisonRiskDetail <- NULL
  }
  if (is.data.frame(dfComparisonRiskDetail)) {
    required <- c("StudyID", "GroupID", "MetricID", "ActionState",
      "LastActionedDate", "DaysSinceAction", "ActionWindowDays")
    missing <- setdiff(required, names(dfComparisonRiskDetail))
    if (length(missing)) {
      stop(
        "dfComparisonRiskDetail is missing required columns: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    # Only the fields that drive highlighting are sent to the browser.
    dfComparisonRiskDetail <- dfComparisonRiskDetail[, required, drop = FALSE]
    for (column in c("StudyID", "GroupID", "MetricID", "ActionState")) {
      dfComparisonRiskDetail[[column]] <- as.character(dfComparisonRiskDetail[[column]])
    }
    dfComparisonRiskDetail$LastActionedDate <-
      format(as.Date(dfComparisonRiskDetail$LastActionedDate), "%Y-%m-%d")
  }
  if (!strRiskScoreMetric %in% dfResults$MetricID) {
    stop(
      "Risk score metric ",
      strRiskScoreMetric,
      " is not present in dfResults.",
      call. = FALSE
    )
  }

  dfCrossStudySummary <- SummarizeCrossStudy(
    dfResults = dfResults,
    strGroupLevel = strGroupLevel,
    dfGroups = dfGroups,
    strRiskScoreMetric = strRiskScoreMetric
  )
  # Forward options using the same pattern as Widget_GroupOverview
  lInput <- list(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    dfSummary = dfCrossStudySummary,
    strGroupLevel = strGroupLevel,
    strGroupLabelKey = "GroupID",
    strSiteRiskMetric = strRiskScoreMetric,
    strComparisonRiskMetric = strComparisonRiskMetric,
    strComparisonRiskLabel = strComparisonRiskLabel,
    dfComparisonRiskDetail = dfComparisonRiskDetail
  )

  # Create widget using the same pattern as Widget_GroupOverview
  lWidget <- htmlwidgets::createWidget(
    name = "Widget_CrossStudyRiskScore",
    purrr::map(
      lInput,
      ~ jsonlite::toJSON(
        .x,
        null = "null",
        na = "string",
        auto_unbox = TRUE
      )
    ),
    width = "100%",
    package = "gsm.kri",
    # gsmViz lives in gsm.vizr; a YAML dependency can only resolve paths inside
    # gsm.kri, so it is handed over here. createWidget() appends it after the
    # widget binding, so bindings must not touch window.gsmViz until renderValue.
    dependencies = list(gsm.vizr::html_dependency_gsm_viz())
  )

  return(lWidget)
}

#' Shiny bindings for Widget_CrossStudyRiskScore
#'
#' @param outputId output variable to read from
#' @param width,height Must be a valid CSS unit
#' @param expr An expression that generates a Widget_CrossStudyRiskScore
#' @param env The environment in which to evaluate expr.
#' @param quoted Is expr a quoted expression?
#'
#' @name Widget_CrossStudyRiskScore-shiny
#' @export
Widget_CrossStudyRiskScoreOutput <- function(
  outputId,
  width = "100%",
  height = "600px"
) {
  htmlwidgets::shinyWidgetOutput(
    outputId,
    "Widget_CrossStudyRiskScore",
    width,
    height,
    package = "gsm.kri"
  )
}

#' @rdname Widget_CrossStudyRiskScore-shiny
#' @export
renderWidget_CrossStudyRiskScore <- function(
  expr,
  env = parent.frame(),
  quoted = FALSE
) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(
    expr,
    Widget_CrossStudyRiskScoreOutput,
    env,
    quoted = TRUE
  )
}
