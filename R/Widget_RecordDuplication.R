#' Record Duplication Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' An interactive htmlwidget that displays record duplication across measurements,
#' nested by Measure → Site → Participant. Duplicate records are highlighted and
#' summary statistics are shown at each level.
#'
#' For the data preparation wrapper, see [Report_RecordDuplication()].
#'
#' @param dfFlagged `data.frame` Long-format data with columns: `subjid`, `GroupID`,
#'   `date`, `measure`, `value`, `is_duplicate`.
#' @param dfMetrics `data.frame` Optional metric metadata to identify prioritized measures.
#'   Should have a `Metric` or `Abbreviation` column.
#' @param strGroupLevel `character` Group level label. Default: `"Site"`.
#' @param vPrioritizedMeasures `character` Vector of measure names that have KRI metrics
#'   configured. These are displayed first with a priority indicator.
#'
#' @return An htmlwidget for record duplication visualization.
#'
#' @export
Widget_RecordDuplication <- function(
  dfFlagged,
  dfMetrics = NULL,

  strGroupLevel = "Site",
  vPrioritizedMeasures = NULL
) {
  stopifnot(is.data.frame(dfFlagged))
  stopifnot(all(c("subjid", "GroupID", "date", "measure", "value", "is_duplicate") %in% names(dfFlagged)))

  lInput <- list(
    dfFlagged = dfFlagged,
    dfMetrics = dfMetrics,
    strGroupLevel = strGroupLevel,
    vPrioritizedMeasures = vPrioritizedMeasures
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
