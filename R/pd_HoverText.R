#' Format a count as a percentage of a denominator
#'
#' @description
#' Internal helper for premature-death hover tooltips. Returns `"42.9%"`-style
#' labels, degrading to an em dash when the count or denominator is missing or
#' the denominator is non-positive.
#'
#' @param n `numeric` Count(s).
#' @param denom `numeric` Denominator (scalar recycled against `n`, or vector).
#'
#' @return A `character` vector the length of `n`.
#' @noRd
pd_PctLabel <- function(n, denom) {
  pct <- paste0(formatC(100 * n / denom, format = "f", digits = 1), "%")
  pct[is.na(n) | is.na(denom) | denom <= 0] <- "\u2014"
  pct
}

#' Format a logical as Yes / No / Unknown
#'
#' @description
#' Internal helper for premature-death hover tooltips.
#'
#' @param x `logical` vector.
#'
#' @return A `character` vector: `TRUE` -> "Yes", `FALSE` -> "No", `NA` -> "Unknown".
#' @noRd
pd_YesNo <- function(x) {
  dplyr::case_when(
    is.na(x) ~ "Unknown",
    x ~ "Yes",
    TRUE ~ "No"
  )
}

#' Death-reason label with "Unknown" fallback
#'
#' @description
#' Internal helper for premature-death reporting. Returns the `deathcls` column
#' of `df` as a character vector, substituting `"Unknown"` for missing values
#' and for an entirely absent column. Single source of truth for the fallback
#' used by [pd_ReasonCounts()] and [pd_ReasonByCountry()].
#'
#' @param df `data.frame` that may or may not carry a `deathcls` column.
#'
#' @return A `character` vector of length `nrow(df)`.
#' @noRd
pd_DeathReason <- function(df) {
  cls <- if ("deathcls" %in% names(df)) {
    as.character(df[["deathcls"]])
  } else {
    rep(NA_character_, nrow(df))
  }
  dplyr::coalesce(cls, "Unknown")
}
