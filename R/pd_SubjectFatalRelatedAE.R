#' Per-subject fatal treatment-related AE flag
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' For each subject in `dfAE`, whether they have at least one adverse event that
#' is both fatal (`aetoxgr == 5`) and treatment-related (`aerel == "RELATED"`,
#' case-insensitive). This is the AE-side signal the premature-death patient
#' listing combines with the death classification (`deathcls`) to derive the
#' Treatment Related column. Centralizing it keeps the rule in one tested place.
#'
#' Comparisons are NA-safe: a row with a missing grade or relatedness does not
#' qualify and never flips a subject to `TRUE`.
#'
#' @param dfAE `data.frame` Mapped AE data with `subjid`, `aetoxgr` (integer
#'   CTCAE grade) and `aerel` (`"RELATED"` / `"NOT RELATED"`).
#'
#' @return A `tibble` with one row per subject: `subjid` and a logical
#'   `has_fatal_related_ae`.
#' @export
pd_SubjectFatalRelatedAE <- function(dfAE) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfAE),
    message = "dfAE is not a data.frame"
  )
  for (col in c("aetoxgr", "aerel")) {
    if (!col %in% names(dfAE)) {
      dfAE[[col]] <- NA
    }
  }
  dfAE %>%
    dplyr::mutate(
      .qual = !is.na(.data$aetoxgr) &
        .data$aetoxgr == 5 &
        toupper(trimws(.data$aerel)) == "RELATED"
    ) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      has_fatal_related_ae = any(.data$.qual, na.rm = TRUE),
      .groups = "drop"
    )
}
