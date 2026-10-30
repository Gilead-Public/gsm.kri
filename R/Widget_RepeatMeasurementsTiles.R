#' Participant Listing widget for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A participant x vital tile grid: one row per participant, one tile per KRI
#' vital, filled by the participant's flag and labelled with the rate, N/D or
#' both. Clicking a participant or any of their tiles (or pressing Enter or
#' Space on one) dispatches a bubbling `rm-tiles-select` event whose `detail`
#' holds `chartId` and `subjid`; the report's filter script uses it to toggle
#' the participant filter. The rendered element exposes the `gsmChart` API
#' that the filter script calls (`data`, `helpers.updateData()`,
#' `helpers.selectRow()`, `helpers.clearSelection()` and
#' `helpers.updateSpec()` for the label mode).
#'
#' @param dfTiles `data.frame` Output of [rm_ParticipantTiles()].
#' @param strLabel `character` Initial tile label: `"both"`, `"rate"` or `"nd"`.
#' @param strId `character` Element ID of the widget.
#' @param nPageSize `integer` Participants per page.
#'
#' @return An htmlwidget.
#' @keywords internal
#' @export
Widget_RepeatMeasurementsTiles <- function(
  dfTiles,
  strLabel = c("both", "rate", "nd"),
  strId = "rm-tiles",
  nPageSize = 50L
) {
  strLabel <- match.arg(strLabel)
  vRequired <- c(
    "subjid", "invid", "country", "vital", "column", "flag",
    "Numerator", "Denominator", "rate", "label_rate", "label_nd", "label_both"
  )
  vMissing <- setdiff(vRequired, names(dfTiles))
  gsm.core::stop_if(
    cnd = !is.data.frame(dfTiles) || length(vMissing) > 0,
    message = paste0("dfTiles needs ", paste(vMissing, collapse = ", "))
  )
  dfVitals <- rm_Vitals()
  vVitals <- unique(dfTiles$vital)
  vVitals <- c(intersect(dfVitals$vital, vVitals), setdiff(vVitals, dfVitals$vital))
  dfColumns <- tibble::tibble(
    vital = vVitals,
    column = dfTiles$column[match(vVitals, dfTiles$vital)],
    label = dplyr::coalesce(dfVitals$label[match(vVitals, dfVitals$vital)], vVitals),
    metric = dfVitals$metric[match(vVitals, dfVitals$vital)]
  )
  vColors <- rm_FlagColors()
  htmlwidgets::createWidget(
    name = "Widget_RepeatMeasurementsTiles",
    x = list(
      tiles = jsonlite::toJSON(dfTiles[vRequired], dataframe = "rows", na = "null"),
      columns = jsonlite::toJSON(dfColumns, dataframe = "rows", na = "null"),
      colors = as.list(vColors[c("Red", "Amber", "Green", "Not evaluable")]),
      label = strLabel,
      pageSize = as.integer(nPageSize)
    ),
    width = "100%",
    height = "auto",
    package = "gsm.kri",
    elementId = strId,
    sizingPolicy = htmlwidgets::sizingPolicy(
      defaultWidth = "100%",
      defaultHeight = "auto",
      knitr.figure = FALSE,
      browser.fill = FALSE
    )
  )
}
