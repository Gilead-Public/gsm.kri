#' Per-subject fatal treatment-related AE flag
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' For each subject in `dfAE`, whether they have at least one adverse event that
#' is both fatal (`aetoxgr == 5`) and treatment-related (`aerel == "RELATED"`,
#' case-insensitive). Also flags fatal (`aetoxgr == 5`) not-treatment-related
#' (`aerel == "NOT RELATED"`) AEs — the AE-side signal for the "No" case in the
#' premature-death Treatment Related column. Centralizing both rules keeps them
#' in one tested place.
#'
#' Comparisons are NA-safe: a row with a missing grade or relatedness does not
#' qualify and never flips a subject to `TRUE`.
#'
#' @param dfAE `data.frame` Mapped AE data with `subjid`, `aetoxgr` (integer
#'   CTCAE grade) and `aerel` (`"RELATED"` / `"NOT RELATED"`).
#'
#' @return A `tibble` with one row per subject: `subjid`, a logical
#'   `has_fatal_related_ae` (a fatal grade-5 `"RELATED"` AE), and a logical
#'   `has_fatal_unrelated_ae` (a fatal grade-5 `"NOT RELATED"` AE).
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
      .fatal = !is.na(.data$aetoxgr) & .data$aetoxgr == 5,
      .rel = toupper(trimws(.data$aerel)),
      .qual_related = .data$.fatal & .data$.rel == "RELATED",
      .qual_unrelated = .data$.fatal & .data$.rel == "NOT RELATED"
    ) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      has_fatal_related_ae = any(.data$.qual_related, na.rm = TRUE),
      has_fatal_unrelated_ae = any(.data$.qual_unrelated, na.rm = TRUE),
      .groups = "drop"
    )
}
