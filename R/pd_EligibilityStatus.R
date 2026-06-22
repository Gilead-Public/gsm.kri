#' Classify eligibility from an exclusion `Source`
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The single definition of the canonical `kri0014` eligibility rule, shared by
#' [pd_PatientListingData()] and [pd_OverviewStats()] so the two cannot drift.
#' `Source` is the per-subject exclusion summary produced by `EXCLUSION.yaml`:
#' `"Neither"` means no inclusion/exclusion or eligibility protocol-deviation
#' violation was recorded (eligible); any other non-missing value means a
#' violation was recorded (ineligible); a missing value means the subject has no
#' exclusion record, so eligibility cannot be asserted (unknown).
#'
#' @param Source `character` Vector of exclusion `Source` values.
#'
#' @return A `character` vector the same length as `Source`: `"Eligible"`,
#'   `"Ineligible"`, or `"Unknown"`.
#' @export
pd_EligibilityStatus <- function(Source) {
  dplyr::case_when(
    is.na(Source) ~ "Unknown",
    Source == "Neither" ~ "Eligible",
    TRUE ~ "Ineligible"
  )
}
