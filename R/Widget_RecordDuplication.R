#' Record Duplication Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' An interactive htmlwidget that displays consecutive repeated measures across
#' measurements, nested by Measure → Site → Participant. Records belonging to a run of
#' `nWindowLength` or more identical consecutive values are highlighted, and repeat
#' window rates are shown at each level.
#'
#' For the data preparation wrapper, see [Report_RecordDuplication()].
#'
#' @param dfFlagged `data.frame` Long-format data with columns: `subjid`, `GroupID`,
#'   `date`, `measure`, `value`, `RunID`, `RunLength`, `IsRepeatRun`,
#'   `IsEvaluableWindow`, and `IsRepeatWindow`, as produced by
#'   [Detect_ConsecutiveRepeats()].
#' @param dfReportingResults `data.frame` Optional. Standard reportingResults data with
#'   columns: `GroupID`, `GroupLevel`, `MetricID`, `Score`, `Flag`. Used to show metric
#'   badges in group headers.
#' @param dfReportingMetrics `data.frame` Optional. Standard reportingMetrics data with
#'   columns: `MetricID`, `Metric`. Currently passed through for future use.
#' @param dfMeasureMetrics `data.frame` Optional. Maps measure names to MetricIDs; columns:
#'   `measure` (character), `MetricID` (character). Used to link measures to metric results.
#' @param strGroupLevel `character` Group level label. Default: `"Site"`.
#' @param vPrioritizedMeasures `character` Vector of measure names that have KRI metrics
#'   configured. These are displayed first with a priority indicator.
#' @param nWindowLength `numeric` Rolling window length *W* used to produce `dfFlagged`.
#'   Displayed in the header so the highlighting rule is self-describing. Default: `3`.
#'
#' @return An htmlwidget for record duplication visualization.
#'
#' @export
Widget_RecordDuplication <- function(
  dfFlagged,
  dfReportingResults = NULL,
  dfReportingMetrics = NULL,
  dfMeasureMetrics = NULL,
  strGroupLevel = "Site",
  vPrioritizedMeasures = NULL,
  nWindowLength = 3
) {
  stopifnot(is.data.frame(dfFlagged))
  stopifnot(all(
    c(
      "subjid", "GroupID", "date", "measure", "value",
      "RunLength", "IsRepeatRun", "IsEvaluableWindow", "IsRepeatWindow"
    ) %in% names(dfFlagged)
  ))

  lInput <- list(
    dfFlagged = dfFlagged,
    dfReportingResults = dfReportingResults,
    dfReportingMetrics = dfReportingMetrics,
    dfMeasureMetrics = dfMeasureMetrics,
    strGroupLevel = strGroupLevel,
    vPrioritizedMeasures = vPrioritizedMeasures,
    nWindowLength = nWindowLength
  )

  lWidget <- htmlwidgets::createWidget(
    name = "Widget_RecordDuplication",
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

#' Shiny bindings for Widget_RecordDuplication
#'
#' @param outputId output variable to read from
#' @param width,height Must be a valid CSS unit
#' @param expr An expression that generates a Widget_RecordDuplication
#' @param env The environment in which to evaluate expr.
#' @param quoted Is expr a quoted expression?
#'
#' @name Widget_RecordDuplication-shiny
#' @export
Widget_RecordDuplicationOutput <- function(
  outputId,
  width = "100%",
  height = "800px"
) {
  htmlwidgets::shinyWidgetOutput(
    outputId,
    "Widget_RecordDuplication",
    width,
    height,
    package = "gsm.kri"
  )
}

#' @rdname Widget_RecordDuplication-shiny
#' @export
renderWidget_RecordDuplication <- function(
  expr,
  env = parent.frame(),
  quoted = FALSE
) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(
    expr,
    Widget_RecordDuplicationOutput,
    env,
    quoted = TRUE
  )
}
