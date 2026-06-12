#' Cross-Study Risk Score Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A widget that generates an interactive cross-study risk score table.
#' Shows a summary view with click-to-expand details for each site.
#'
#' For a working example see [Cross-Study KRI Report](https://gilead-biostats.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
#'
#' @param dfResults `data.frame` Full results data for details.
#' @param dfMetrics `data.frame` Metadata about metrics/KRIs.
#' @param dfGroups `data.frame` Metadata about groups (sites/studies).
#' @param strGroupLevel `character` The group level. Default is 'Site'.
#'
#' @return An htmlwidget for cross-study risk score visualization.
#'
#' @export
Widget_CrossStudyRiskScore <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site"
) {
  stopifnot(is.data.frame(dfResults))
  stopifnot(is.data.frame(dfMetrics))
  stopifnot(is.data.frame(dfGroups))
  # Check that Analysis_srs0001 is present
  stopifnot("Analysis_srs0001" %in% dfResults$MetricID)

  dfCrossStudySummary <- SummarizeCrossStudy(
    dfResults = dfResults,
    strGroupLevel = strGroupLevel,
    dfGroups = dfGroups
  )
  # Forward options using the same pattern as Widget_GroupOverview
  lInput <- list(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    dfSummary = dfCrossStudySummary,
    strGroupLevel = strGroupLevel,
    strGroupLabelKey = "GroupID",
    strSiteRiskMetric = "Analysis_srs0001"
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
    package = "gsm.kri"
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
