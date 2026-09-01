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
#' of `df` as a character vector, substituting `"Unknown"` for missing, blank, or
#' whitespace-only values and for an entirely absent column. Single source of
#' truth for the fallback used by [pd_ReasonCounts()] and [pd_ReasonByCountry()].
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
  # Treat blank / whitespace-only deathcls as missing (not a real reason) so the
  # reason bars and the listing's treatment_related column agree on "no class".
  dplyr::coalesce(dplyr::na_if(trimws(cls), ""), "Unknown")
}

#' Country label with "Unknown" fallback
#'
#' @description
#' Internal helper for premature-death reporting. Coalesces a country vector to
#' `"Unknown"` for missing, blank, or whitespace-only values. Single source of
#' truth so the bucket bars, the per-country reason split, the enrolled-count
#' lookup, and the JS country->site click map all key on the same label -- so an
#' "Unknown" bar resolves to the unmapped-subject sites instead of an empty filter.
#'
#' @param x A vector coercible to `character` (e.g. `Mapped_SUBJ$country`).
#'
#' @return A `character` vector the length of `x`.
#' @noRd
pd_CountryLabel <- function(x) {
  dplyr::coalesce(dplyr::na_if(trimws(as.character(x)), ""), "Unknown")
}
