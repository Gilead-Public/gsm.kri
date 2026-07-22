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
#' Horizontal single-series bars. The tooltip formatter and callbacks are
#' attached in `Widget_PrematureDeathReasonBar.js`; this returns only the
#' serializable spec.
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
    )
  )
}
