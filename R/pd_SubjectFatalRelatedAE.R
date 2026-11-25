#' Per-subject fatal treatment-related AE flag
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' For each subject in `dfAE`, whether they have at least one adverse event that
#' is both fatal and treatment-related, fatal and not treatment-related, or fatal
#' with unknown relatedness — the AE-side signals for the premature-death
#' Treatment Related column. Centralizing the rules keeps them in one tested
#' place.
#'
#' An AE is fatal when its outcome is fatal (`aeout == "Fatal"`), it is graded
#' CTCAE 5 (`aetoxgr == 5`), or it is flagged as resulting in death
#' (`aesdth == "Yes"`). Relatedness comes from `aereldrv` (`"Yes"` / `"No"`),
#' falling back to `aerel` (`"RELATED"` / `"NOT RELATED"`) when `aereldrv` is
#' absent or missing. Comparisons are case-insensitive and NA-safe: a missing
#' field never makes an AE fatal or related.
#'
#' @param dfAE `data.frame` Mapped AE data with `subjid` and any of `aeout`,
#'   `aetoxgr`, `aesdth`, `aereldrv` and `aerel`.
#'
#' @return A `tibble` with one row per subject: `subjid` and the logicals
#'   `has_fatal_related_ae`, `has_fatal_unrelated_ae` and `has_fatal_unknown_ae`
#'   (a fatal AE with missing relatedness).
#' @export
pd_SubjectFatalRelatedAE <- function(dfAE) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfAE),
    message = "dfAE is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !"subjid" %in% names(dfAE),
    message = "dfAE must contain 'subjid'"
  )
  pd_FlagFatalAE(dfAE) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      has_fatal_related_ae = any(.data$.fatal & .data$.related %in% "Yes"),
      has_fatal_unrelated_ae = any(.data$.fatal & .data$.related %in% "No"),
      has_fatal_unknown_ae = any(.data$.fatal & is.na(.data$.related)),
      .groups = "drop"
    )
}

#' Flag fatal AEs and their relatedness row by row
#'
#' @param dfAE `data.frame` Mapped AE data.
#' @return `dfAE` with a logical `.fatal` and a character `.related`
#'   (`"Yes"`, `"No"` or `NA`).
#' @keywords internal
#' @noRd
pd_FlagFatalAE <- function(dfAE) {
  for (col in c("aetoxgr", "aeout", "aesdth", "aereldrv", "aerel")) {
    if (!col %in% names(dfAE)) {
      dfAE[[col]] <- rep(NA, nrow(dfAE))
    }
  }
  norm <- function(x) toupper(trimws(as.character(x)))
  dfAE %>%
    dplyr::mutate(
      .fatal = (!is.na(.data$aetoxgr) & .data$aetoxgr == 5) |
        norm(.data$aeout) %in% "FATAL" |
        norm(.data$aesdth) %in% c("YES", "Y"),
      .related = dplyr::coalesce(
        dplyr::case_when(
          norm(.data$aereldrv) %in% c("YES", "Y") ~ "Yes",
          norm(.data$aereldrv) %in% c("NO", "N") ~ "No"
        ),
        dplyr::case_when(
          norm(.data$aerel) %in% "RELATED" ~ "Yes",
          norm(.data$aerel) %in% "NOT RELATED" ~ "No"
        )
      )
    )
}
