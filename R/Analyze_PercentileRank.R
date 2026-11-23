#' Score groups by percentile rank
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Ranks groups on `strValueCol` (highest first) and scores each group as
#' `100 * (n - r) / n`, where `n` is the number of ranked groups and `r` is the
#' group's competition rank (1 + the number of groups with a strictly higher
#' value). Tied groups share the better rank. With thresholds `c(80, 90)` and
#' `gsm.core::Flag()`'s `[a, b)` intervals, the top 10% of groups score `>= 90`
#' and the next 10% score `>= 80`. Groups with a missing value are not ranked
#' and get a missing `Score`.
#'
#' @param dfTransformed `data.frame` One row per group, e.g. from
#'   `gsm.core::Transform_Rate()`.
#' @param strValueCol `character` Column to rank on. Default `"Numerator"`.
#'
#' @return `dfTransformed` with a `Score` column (0-100), sorted by `Score`.
#'
#' @examples
#' df <- data.frame(GroupID = LETTERS[1:5], Numerator = c(40, 25, 25, 10, 0))
#' Analyze_PercentileRank(df)
#' @export
Analyze_PercentileRank <- function(dfTransformed, strValueCol = "Numerator") {
  stopifnot(
    "dfTransformed is not a data.frame" = is.data.frame(dfTransformed),
    "strValueCol not found in dfTransformed" = strValueCol %in%
      names(dfTransformed)
  )

  vValue <- dfTransformed[[strValueCol]]
  vRanked <- vValue[!is.na(vValue)]
  n <- length(vRanked)
  vRank <- vapply(vValue, function(x) 1 + sum(vRanked > x), numeric(1))
  dfTransformed$Score <- ifelse(is.na(vValue), NA_real_, 100 * (n - vRank) / n)

  dfTransformed[order(dfTransformed$Score), , drop = FALSE]
}
