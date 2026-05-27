#' Portfolio Overview Widget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A widget that renders a portfolio-level rollup table with one column per
#' KRI metric and one row per drill-down bucket (overall total plus categories
#' from study-level grouping params). Cells display
#' numerator / denominator / rate. Includes a filter bar (D2) and expandable
#' drill-down rows that reveal per-study contributions (D4).
#'
#' For a working example see the [Portfolio Overview Report](https://gilead-biostats.github.io/gsm.kri/examples/Example_PortfolioOverview.html).
#'
#' @param dfResults `data.frame` Cross-study KRI results.
#' @param dfMetrics `data.frame` Metadata about metrics/KRIs.
#' @param dfGroups `data.frame` Study-level group metadata in long format.
#' @param strGroupLevel `character` The group level. Default `"Site"`.
#' @param vGroupParams `character` Vector of `Param` values from `dfGroups` to
#'   use as drill-down categories.
#' @param vFilterParams `character` Vector of `Param` values exposed in the
#'   filter bar (D2). Defaults to therapeutic area, phase, status. StudyID is
#'   always available as a filter regardless of this argument.
#'
#' @return An htmlwidget rendering the portfolio overview table.
#'
#' @export
Widget_PortfolioOverview <- function(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  vGroupParams = c(
    "therapeutic_area",
    "protocol_indication",
    "phase",
    "status",
    "product"
  ),
  vFilterParams = c("therapeutic_area", "phase", "status")
) {
  stopifnot(is.data.frame(dfResults))
  stopifnot(is.data.frame(dfMetrics))
  stopifnot(is.data.frame(dfGroups))
  stopifnot(is.character(vGroupParams))
  stopifnot(is.character(vFilterParams))

  dfSummary <- SummarizePortfolioOverview(
    dfResults = dfResults,
    dfGroups = dfGroups,
    strGroupLevel = strGroupLevel,
    vGroupParams = vGroupParams
  )

  # Pre-compute per-study contribution table for D4 expand/collapse rows.
  # One row per (StudyID, MetricID) at the latest snapshot for the requested
  # GroupLevel, with study-level group params attached so the JS layer can
  # resolve which studies belong to each drill-down bucket.
  if ("SnapshotDate" %in% colnames(dfResults)) {
    # Per-study latest snapshot: studies snapshot on independent cadences,
    # so a global max would silently drop any study whose most recent
    # snapshot pre-dates the portfolio max.
    dfPerStudyResults <- dfResults %>%
      dplyr::group_by(.data$StudyID) %>%
      dplyr::filter(.data$SnapshotDate == max(.data$SnapshotDate, na.rm = TRUE)) %>%
      dplyr::ungroup()
  } else {
    dfPerStudyResults <- dfResults
  }

  dfPerStudyRaw <- dfPerStudyResults %>%
    dplyr::filter(.data$GroupLevel == strGroupLevel)

  has_flag <- "Flag" %in% colnames(dfPerStudyRaw)

  dfPerStudy <- dfPerStudyRaw %>%
    dplyr::group_by(.data$StudyID, .data$MetricID) %>%
    dplyr::summarise(
      Numerator = sum(.data$Numerator, na.rm = TRUE),
      Denominator = sum(.data$Denominator, na.rm = TRUE),
      FlagN2 = if (has_flag) sum(.data$Flag == -2, na.rm = TRUE) else 0L,
      FlagN1 = if (has_flag) sum(.data$Flag == -1, na.rm = TRUE) else 0L,
      Flag0 = if (has_flag) sum(.data$Flag == 0, na.rm = TRUE) else 0L,
      FlagP1 = if (has_flag) sum(.data$Flag == 1, na.rm = TRUE) else 0L,
      FlagP2 = if (has_flag) sum(.data$Flag == 2, na.rm = TRUE) else 0L,
      FlagNA = if (has_flag) sum(is.na(.data$Flag)) else dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      Rate = ifelse(
        .data$Denominator > 0,
        .data$Numerator / .data$Denominator,
        NA_real_
      )
    )

  # Wide table of per-study attributes, used by the JS filter bar (D2) and the
  # drill-down rendering (D4).
  if (all(c("StudyID", "Param", "Value") %in% colnames(dfGroups))) {
    dfStudyAttrs <- dfGroups %>%
      dplyr::filter(.data$Param %in% unique(c(vGroupParams, vFilterParams))) %>%
      dplyr::select("StudyID", "Param", "Value") %>%
      dplyr::distinct()
  } else {
    dfStudyAttrs <- data.frame(
      StudyID = character(0),
      Param = character(0),
      Value = character(0)
    )
  }

  # Q2: metric column order is by MetricID ascending.
  vMetricOrder <- sort(unique(dfSummary$MetricID))

  lInput <- list(
    dfSummary = dfSummary,
    dfPerStudy = dfPerStudy,
    dfStudyAttrs = dfStudyAttrs,
    dfMetrics = dfMetrics,
    vMetricOrder = vMetricOrder,
    vGroupParams = vGroupParams,
    vFilterParams = vFilterParams,
    strGroupLevel = strGroupLevel
  )

  lWidget <- htmlwidgets::createWidget(
    name = "Widget_PortfolioOverview",
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

#' Shiny bindings for Widget_PortfolioOverview
#'
#' @param outputId output variable to read from
#' @param width,height Must be a valid CSS unit
#' @param expr An expression that generates a Widget_PortfolioOverview
#' @param env The environment in which to evaluate expr.
#' @param quoted Is expr a quoted expression?
#'
#' @name Widget_PortfolioOverview-shiny
#' @export
Widget_PortfolioOverviewOutput <- function(
  outputId,
  width = "100%",
  height = "600px"
) {
  htmlwidgets::shinyWidgetOutput(
    outputId,
    "Widget_PortfolioOverview",
    width,
    height,
    package = "gsm.kri"
  )
}

#' @rdname Widget_PortfolioOverview-shiny
#' @export
renderWidget_PortfolioOverview <- function(
  expr,
  env = parent.frame(),
  quoted = FALSE
) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(
    expr,
    Widget_PortfolioOverviewOutput,
    env,
    quoted = TRUE
  )
}
