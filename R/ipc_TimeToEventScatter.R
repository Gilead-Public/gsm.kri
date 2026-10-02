#' IP Compliance time-to-event scatter
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Days since enrollment (y) against days to event (x), one trace per status;
#' the legend follows the stack order. Participants without an event sit on the dashed diagonal.
#' Square markers are dosed participants, circles are not dosed. The report's
#' filter script registers the widget on render and redraws it on filter and
#' legend changes.
#'
#' @param dfIPC `data.frame` Output of [ipc_ClassifyParticipants()].
#' @param nMaxDays `numeric` Largest day count in the study, so the three
#'   scatters share one range.
#' @param strId `character` Scatter id handed to the filter script.
#'
#' @return A `plotly` htmlwidget.
#' @keywords internal
#' @export
ipc_TimeToEventScatter <- function(dfIPC, nMaxDays, strId) {
  rlang::check_installed("plotly", reason = "to run `ipc_TimeToEventScatter()`")
  vColors <- ipc_StatusColors()
  df <- dfIPC[!is.na(dfIPC$days_since_enrl), ]
  # 5% padding keeps edge points clear; the axis starts at 0 unless an event
  # predates enrollment.
  nPad <- 0.05 * nMaxDays
  nMin <- min(0, df$days_to_event, df$days_since_enrl)
  vRange <- c(if (nMin < 0) nMin - nPad else 0, nMaxDays + nPad)

  # Dosed statuses draw first so not-dosed points on the diagonal stay visible
  # over Ongoing; legendrank keeps the legend in stack order.
  vDrawOrder <- names(vColors)[c(1, 5, 7, 2, 3, 4, 6)]
  p <- plotly::plot_ly()
  for (strStatus in vDrawOrder) {
    d <- df[df$status %in% strStatus, ]
    if (nrow(d) == 0) {
      next
    }
    p <- plotly::add_markers(
      p,
      x = d$days_to_event,
      y = d$days_since_enrl,
      name = strStatus,
      legendrank = match(strStatus, names(vColors)),
      # Symbol inside marker: add_markers(symbol =) would add plotly's own
      # symbol legend.
      marker = list(
        color = vColors[[strStatus]],
        symbol = ifelse(d$dosed %in% "Y", "square", "circle"),
        size = 8,
        opacity = 0.85,
        line = list(color = "#FFFFFF", width = 1)
      ),
      # Per point: subjid, invid, country, dosed. The filter script reads it.
      customdata = I(Map(
        function(a, b, c, e) list(a, b, c, e),
        d$subjid,
        d$invid,
        d$country,
        dplyr::coalesce(d$dosed, "")
      )),
      hovertemplate = paste0(
        "<b>%{customdata[0]}</b><br>",
        strStatus,
        "<br>Site: %{customdata[1]}<br>Country: %{customdata[2]}",
        "<br>Days since enrollment: %{y}<br>Days to event: %{x}<extra></extra>"
      )
    )
  }
  p <- plotly::layout(
    p,
    xaxis = list(
      title = "Days from enrollment to event or today",
      range = vRange,
      zeroline = FALSE
    ),
    yaxis = list(
      title = "Days since enrollment",
      range = vRange,
      zeroline = FALSE
    ),
    shapes = list(list(
      type = "line",
      x0 = 0,
      y0 = 0,
      x1 = vRange[[2]],
      y1 = vRange[[2]],
      line = list(color = "#8A9BB3", width = 1, dash = "dash")
    )),
    legend = list(
      orientation = "h",
      x = 0,
      xanchor = "left",
      y = 1.02,
      yanchor = "bottom"
    )
  )
  htmlwidgets::onRender(
    p,
    "function (el, x, id) { if (window.ipcRegisterScatter) window.ipcRegisterScatter(el, id); }",
    data = strId
  )
}
