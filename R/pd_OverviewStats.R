#' Overview summary statistics for the premature-death report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Computes the four headline numbers shown in the report's Overview table from
#' the single classified-cohort source of truth ([pd_Classify()] output), so the
#' table cannot drift from the bucket bars and scatter. "Premature" is the union
#' of the two death categories ([pd_CategoryLevels()] entries 1-2); the
#' ineligible share is taken over that same premature set, so numerator and
#' denominator always describe one cohort.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()]: one row per
#'   enrolled (randomized) subject, with `subjid`, `invid`, and `Category`.
#' @param dfExclusion `data.frame` (optional) Mapped exclusion data with `subjid`
#'   and `Source` (as produced by `EXCLUSION.yaml`). When absent (or lacking a
#'   `Source` column), `has_eligibility` is `FALSE` and the ineligible counts are
#'   `NA` (the report renders the cell as a dash rather than asserting zero).
#' @param nWindowDays `numeric` Premature-death window in days. Default 90.
#'
#' @return A named `list`: `nEnrolled`, `nSites`, `nPremature`, `nPrematureRate`,
#'   `nIneligible`, `nIneligibleRate`, `has_eligibility`.
#' @export
pd_OverviewStats <- function(
  dfClassified,
  dfExclusion = NULL,
  nWindowDays = 90
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfClassified),
    message = "dfClassified is not a data.frame"
  )

  nEnrolled <- nrow(dfClassified)
  nSites <- length(unique(dfClassified$invid[!is.na(dfClassified$invid)]))

  death_levels <- pd_CategoryLevels(nWindowDays)[1:2]
  is_premature <- as.character(dfClassified$Category) %in% death_levels
  nPremature <- sum(is_premature)
  nPrematureRate <- if (nEnrolled > 0) 100 * nPremature / nEnrolled else 0

  has_eligibility <- !is.null(dfExclusion) && "Source" %in% names(dfExclusion)
  if (has_eligibility) {
    # First-match join (duplicates collapse to the first row, same as the
    # distinct()+slice(1) the listing uses). Premature subjects with no exclusion
    # row come back NA -> "Unknown" -> not ineligible.
    Source <- dfExclusion$Source[
      match(dfClassified$subjid[is_premature], dfExclusion$subjid)
    ]
    nIneligible <- sum(pd_EligibilityStatus(Source) == "Ineligible")
    nIneligibleRate <- if (nPremature > 0) 100 * nIneligible / nPremature else 0
  } else {
    nIneligible <- NA_real_
    nIneligibleRate <- NA_real_
  }

  list(
    nEnrolled = nEnrolled,
    nSites = nSites,
    nPremature = nPremature,
    nPrematureRate = nPrematureRate,
    nIneligible = nIneligible,
    nIneligibleRate = nIneligibleRate,
    has_eligibility = has_eligibility
  )
}
