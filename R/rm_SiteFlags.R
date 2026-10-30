#' Site KRI flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The site-level `kri0020a`–`f` flags from each metric's latest snapshot,
#' keyed by vital. A site without a flag in that snapshot is `NA` (not
#' evaluated).
#'
#' @param dfResults `data.frame` Reporting results.
#'
#' @return A named `list` (vital to a named list of site flags); empty when
#'   `dfResults` has no `kri0020` site results.
#' @keywords internal
#' @export
rm_SiteFlags <- function(dfResults) {
  vNeeded <- c("MetricID", "GroupLevel", "GroupID", "Flag")
  if (is.null(dfResults) || !all(vNeeded %in% names(dfResults))) {
    return(stats::setNames(list(), character(0)))
  }
  df <- dfResults[grepl("^Analysis_kri0020[a-f]$", dfResults$MetricID) &
    dfResults$GroupLevel %in% "Site", ]
  # Pick each metric's latest snapshot before reading flags, so a missing
  # latest flag stays not evaluated instead of reviving an older one.
  if ("SnapshotDate" %in% names(df) && nrow(df) > 0) {
    vDate <- as.Date(df$SnapshotDate)
    bLatest <- vDate == stats::ave(vDate, df$MetricID, FUN = function(x) max(x, na.rm = TRUE))
    df <- df[bLatest %in% TRUE, ]
  }
  dfVitals <- rm_Vitals()
  df$vital <- dfVitals$vital[match(sub("^Analysis_", "", df$MetricID), dfVitals$metric)]
  lapply(split(df, df$vital), function(d) {
    as.list(stats::setNames(as.integer(d$Flag), as.character(d$GroupID)))
  })
}
