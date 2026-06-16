#' Randomization-to-event scatter
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Scatter of every enrolled subject from [pd_Classify()]: x = `x_anchor` (death
#' day for deaths; the window boundary for "alive at window"; follow-up for
#' "alive prior"; discontinuation day for discontinuations), y = `follow_up`
#' (days from randomization to snapshot). Colored by category; each category
#' (including the two death categories) is a separate legend entry (SI-1 design
#' decision: no grouped "Death within `nWindowDays` days" heading). Pass
#' `vXRange`/`vYRange` (computed study-wide by the report) to fix a shared range
#' across the study/country/site views (AXIS-1). Each point's `customdata` packs
#' `[hover, country, invid]` so the report can filter points client-side.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#' @param nWindowDays `numeric` Window in days (color/legend vocabulary). Default 90.
#' @param vXRange `numeric(2)` Optional fixed x-axis range. `NULL` autoranges.
#' @param vYRange `numeric(2)` Optional fixed y-axis range. `NULL` autoranges.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_RandToDeathScatter <- function(
  dfClassified,
  nWindowDays = 90,
  vXRange = NULL,
  vYRange = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfClassified),
    message = "dfClassified is not a data.frame"
  )
  rlang::check_installed("plotly", reason = "to run `pd_RandToDeathScatter()`")

  cat_colors <- pd_CategoryColors(nWindowDays)

  df <- dfClassified %>%
    dplyr::mutate(
      hover = paste0(
        "Country: ",
        .data$country,
        "<br>Site: ",
        .data$invid,
        "<br>Subject: ",
        .data$subjid,
        "<br>Category: ",
        as.character(.data$Category),
        "<br>Days (x): ",
        round(.data$x_anchor),
        "<br>Follow-up: ",
        round(.data$follow_up),
        "d"
      )
    )

  # plot_ly() seeds an empty base trace. It is inert in the report -- absent from
  # the legend, its placeholder x renders no marker, and the point filter skips
  # it (no customdata) -- and is intentionally left: the rmarkdown widget render
  # re-materializes it from plotly's internal trace state, so neither an attrs
  # prune nor a pre-built x$data removes it without fragile internals work.
  p <- plotly::plot_ly()
  for (ct in pd_CategoryLevels(nWindowDays)) {
    d <- dplyr::filter(df, .data$Category == ct)
    if (nrow(d) == 0) {
      next
    }
    p <- plotly::add_markers(
      p,
      x = d$x_anchor,
      y = d$follow_up,
      # Separate legend entry per category, named by its full label (SI-1).
      name = ct,
      marker = list(color = unname(cat_colors[ct])),
      # I(Map(...)) keeps customdata a per-point [hover, country, invid] array
      # under plotly's auto_unbox; the report filters scatter points by
      # customdata[1] (country) / customdata[2] (invid).
      customdata = I(Map(
        function(h, c, s) list(h, c, s),
        d$hover,
        ifelse(is.na(d$country), "", d$country),
        ifelse(is.na(d$invid), "", d$invid)
      )),
      hovertemplate = "%{customdata[0]}<extra></extra>"
    )
  }
  xaxis <- list(title = "Days from Randomization to Event")
  yaxis <- list(
    title = "Days from Randomization to Snapshot",
    rangemode = "tozero"
  )
  if (!is.null(vXRange)) {
    xaxis$range <- vXRange
  }
  if (!is.null(vYRange)) {
    yaxis$range <- vYRange
  }

  plotly::layout(
    p,
    xaxis = xaxis,
    yaxis = yaxis,
    legend = list(title = list(text = "Category"))
  )
}
