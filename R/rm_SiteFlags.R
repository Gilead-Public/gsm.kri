#' Site KRI flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The latest site-level `kri0020a`–`f` flag per site, keyed by vital.
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
    dfResults$GroupLevel %in% "Site" & !is.na(dfResults$Flag), ]
  if ("SnapshotDate" %in% names(df) && nrow(df) > 0) {
    df <- df[as.Date(df$SnapshotDate) == max(as.Date(df$SnapshotDate)), ]
  }
  dfVitals <- rm_Vitals()
  df$vital <- dfVitals$vital[match(sub("^Analysis_", "", df$MetricID), dfVitals$metric)]
  lapply(split(df, df$vital), function(d) {
    as.list(stats::setNames(as.integer(d$Flag), as.character(d$GroupID)))
  })
}
