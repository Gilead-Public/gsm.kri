#' Build per-point hover text and customdata for the scatter
#'
#' @description
#' Adds `hover` (character) and `pd_customdata` (plain list-column) to
#' `dfClassified`. Idempotent: if both columns are already present the frame is
#' returned unchanged, so the report can call `pd_ScatterData()` once in the
#' setup chunk and pass `dfScatter` to every scatter view without redundant work.
#'
#' `pd_customdata` is a **plain** list-column (no `I()`). Apply `I()` fresh at
#' `plotly::add_markers()` time so `dplyr::filter()` inside the loop cannot strip
#' the `AsIs` class and break the single-point case.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#'
#' @return `dfClassified` with columns `hover` and `pd_customdata` added (or
#'   unchanged if already present).
#' @noRd
pd_ScatterData <- function(dfClassified) {
  if (all(c("hover", "pd_customdata") %in% names(dfClassified))) {
    return(dfClassified)
  }
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
        round(.data$x_anchor)
      )
    )
  df$pd_customdata <- Map(
    function(h, c, s) list(h, c, s),
    df$hover,
    ifelse(is.na(df$country), "", df$country),
    ifelse(is.na(df$invid), "", df$invid)
  )
  df
}

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
#' Retained on Plotly; migration to a `gsm.viz` renderer is deferred with #120,
#' pending a generic gsm.viz scatter helper (the bucket and reason bars migrated
#' to gsm.viz in #264).
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()]. May already carry
#'   the `hover`/`pd_customdata` columns built by [pd_ScatterData()] — in that
#'   case the per-point build is skipped (idempotent).
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

  df <- pd_ScatterData(dfClassified)

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
      # I(d$pd_customdata) keeps customdata a per-point [hover, country, invid]
      # array under plotly's auto_unbox; the report filters scatter points by
      # customdata[1] (country) / customdata[2] (invid). I() applied HERE (not
      # inside pd_ScatterData) so dplyr::filter() cannot strip the AsIs class.
      customdata = I(d$pd_customdata),
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
