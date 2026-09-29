#' Cross-Study Risk Score Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A widget that generates an interactive cross-study risk score table.
#' Shows a summary view with click-to-expand details for each site.
#'
#' For a working example see [Cross-Study KRI Report](https://gilead-public.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
#'
#' @param dfResults `data.frame` Full results data for details.
#' @param dfMetrics `data.frame` Metadata about metrics/KRIs.
#' @param dfGroups `data.frame` Metadata about groups (sites/studies).
#' @param strGroupLevel `character` The group level. Default is 'Site'.
#' @param strRiskScoreMetric `character` Risk score MetricID to display.
#'   Defaults to `"Analysis_srs0001"`.
#'
#' @return An htmlwidget for cross-study risk score visualization.
#'
#' @export
Widget_CrossStudyRiskScore <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  strRiskScoreMetric = "Analysis_srs0001"
) {
  stopifnot(is.data.frame(dfResults))
  stopifnot(is.data.frame(dfMetrics))
  stopifnot(is.data.frame(dfGroups))
  stopifnot(is.character(strRiskScoreMetric) && length(strRiskScoreMetric) == 1)
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
  strWeightingSummary <- NULL
  if (all(c("MetricID", "Flag", "RiskScoreWeight") %in% names(dfMetrics))) {
    strWeightingSummary <- Report_SRSWeighting(
      dfMetrics = dfMetrics,
      dfResults = dfResults
    ) %>%
      as.character()
  }

  # Forward options using the same pattern as Widget_GroupOverview
  lInput <- list(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    dfSummary = dfCrossStudySummary,
    strWeightingSummary = strWeightingSummary,
    strGroupLevel = strGroupLevel,
    strGroupLabelKey = "GroupID",
    strSiteRiskMetric = strRiskScoreMetric
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
