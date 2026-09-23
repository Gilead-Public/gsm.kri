#' Long rows for the reason bar chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Flattens a reason slice into the long data frame the `gsm.viz` reason widget
#' consumes.
#'
#' @param slice A `list(reason, n, hover)` from `pd_ReasonSlice` /
#'   [pd_ReasonByCountry()].
#'
#' @return A `data.frame` with `reason`, `n`, and `hover` columns.
#' @export
pd_ReasonRows <- function(slice) {
  data.frame(
    reason = slice$reason,
    n = as.integer(slice$n),
    hover = slice$hover,
    stringsAsFactors = FALSE
  )
}

#' Serializable gsm.viz `bars` spec for the reason distribution chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Horizontal single-series bars, each carrying its count on the bar when the
#' bar is long enough to hold the label. Ready to hand to [gsm.vizr::bars()];
#' the tooltip formatter is attached here as a `js_hook`.
#'
#' @param reason_order `character` or `NULL`. Explicit category order for the
#'   reasons. gsm.viz orders categories alphanumerically unless `scales$x$order`
#'   is set (`sort`/`sortDir` only pick the top-N when `nCategories` is capped,
#'   which this chart does not use). Pass the reasons in count order to keep the
#'   count sort the former Plotly chart got from `stats::reorder(reason, n)`.
#'   `NULL` (default) leaves the axis alphanumeric.
#'
#' @return A named `list` — a `gsm.viz` `bars` spec without callbacks.
#' @export
pd_ReasonBarSpec <- function(reason_order = NULL) {
  x <- list(label = "Reason")
  if (!is.null(reason_order)) {
    x$order <- as.list(reason_order)
  }
  list(
    mapping = list(x = "reason", y = "n"),
    orientation = "horizontal",
    position = "stack",
    stat = "identity",
    scales = list(
      x = x,
      y = list(label = "Premature Deaths")
    ),
    # Counts centered in each bar. gsm.viz can also place them past the bar end,
    # but the longest bar reaches the axis maximum, so its label lands outside
    # the canvas and is clipped. The cost of centering: gsm.viz blanks a label
    # whose bar is under 16px long instead of nudging it outside.
    annotations = list(
      labels = list(segment = list(display = TRUE))
    ),
    # hover carries the pre-built "Subjects: N<br>% of premature deaths: X%"
    # lines (pd_HoverText); split on <br> into the tooltip's per-line array.
    tooltip = list(
      formatter = gsm.vizr::js_hook(
        "
      function (count, context, details) {
        var d = (details && details.datum) || {};
        return d.hover ? String(d.hover).split('<br>') : '';
      }"
      )
    )
  )
}
