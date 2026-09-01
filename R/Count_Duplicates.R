#' Count Consecutive Repeated Measures
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Metric-workflow entry point for the Repeat Measurement Rate. Wraps
#' [Detect_ConsecutiveRepeats()] and returns record-level window indicators that
#' [gsm.core::Input_Rate()] sums into a subject-level rate:
#'
#' - numerator = `sum(IsRepeatWindow)` -- rolling windows of length *W* whose values are all identical
#' - denominator = `sum(IsEvaluableWindow)` -- total evaluable windows, `total_measurements - (W - 1)`
#'
#' @inheritParams Detect_ConsecutiveRepeats
#'
#' @return A `data.frame` with one row per non-missing measurement record for the requested
#'   measure, ordered by subject and date, carrying the input columns plus `RunID`,
#'   `RunLength`, `IsRepeatRun`, `IsEvaluableWindow`, and `IsRepeatWindow`. See
#'   [Detect_ConsecutiveRepeats()] for the column definitions.
#'
#' @details
#' Under the rolling-window rule, only *consecutive* identical values count. Given `W = 3`:
#'
#' | Measurements | Numerator | Denominator | Rate |
#' |---|---|---|---|
#' | 10, 10, 5, 3, 10 | 0 | 3 | 0% |
#' | 10, 10, 10, 10, 10 | 3 | 3 | 100% |
#' | 10, 10, 10, 1, 5, 6 | 1 | 4 | 25% |
#'
#' Subjects with fewer than *W* non-missing measurements return rows with
#' `IsEvaluableWindow = 0`, contributing nothing to either total, so they are excluded from
#' scoring rather than scored as a rate of 0.
#'
#' @examples
#' df_vs <- data.frame(
#'   subjid = rep(c("S1", "S2"), each = 5),
#'   vs_dt = rep(as.Date("2024-01-01") + seq(0, 120, by = 30), 2),
#'   weight = c(75, 75, 75, 75, 75, 80, 81, 80, 82, 83)
#' )
#' dfWindows <- Count_Duplicates(df_vs, strValueCol = "weight", nWindowLength = 3)
#'
#' # Subject-level numerator / denominator
#' stats::aggregate(
#'   cbind(Numerator = IsRepeatWindow, Denominator = IsEvaluableWindow) ~ subjid,
#'   data = dfWindows, FUN = sum
#' )
#'
#' @export
Count_Duplicates <- function(
  df,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  dfWindows <- Detect_ConsecutiveRepeats(
    df = df,
    strSubjectCol = strSubjectCol,
    strDateCol = strDateCol,
    strValueCol = strValueCol,
    strMeasureCol = strMeasureCol,
    strMeasureVal = strMeasureVal,
    nWindowLength = nWindowLength
  )

  LogMessage(
    level = "info",
    message = "Counted {sum(dfWindows$IsRepeatWindow)} repeat window(s) of length {ParseWindowLength(nWindowLength)} across {sum(dfWindows$IsEvaluableWindow)} evaluable window(s) for [ {strValueCol} ].",
    cli_detail = "bullet"
  )

  return(dfWindows)
}
