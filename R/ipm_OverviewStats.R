#' IP Monitoring overview figures
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The ten study-wide overview figures in report order. Non-starter figures
#' are shares of enrolled participants; the four treatment completion statuses
#' are shares of dosed participants.
#'
#' @param dfIPM `data.frame` Output of [ipm_ClassifyParticipants()].
#' @param bHasPTD `logical` Whether `drv_drg_completion` was delivered. When
#'   `FALSE`, the four treatment completion figures are `NA`.
#'
#' @return A `tibble` with `label`, `n`, `pct` (`NA` for a zero denominator)
#'   and `base` (`"enrolled"`, `"dosed"`, or `NA` for Total enrolled).
#' @keywords internal
#' @export
ipm_OverviewStats <- function(dfIPM, bHasPTD) {
  vNotDosed <- c(
    "Potential IP non-starter - within window",
    "Potential IP non-starter - outside window",
    "Confirmed IP non-starter"
  )
  vDosed <- c(
    "Treatment ongoing",
    "Treatment complete per protocol",
    "Premature treatment discontinuation",
    "Potential premature treatment discontinuation"
  )
  nEnrolled <- nrow(dfIPM)
  nDosed <- sum(dfIPM$dosed %in% "Y")
  n_status <- function(x) sum(dfIPM$status %in% x)
  stats <- tibble::tibble(
    label = c(
      "Total enrolled",
      "Confirmed dosed",
      vNotDosed,
      "Confirmed IP non-starter with WoC",
      vDosed
    ),
    n = c(
      nEnrolled,
      nDosed,
      vapply(vNotDosed, n_status, integer(1), USE.NAMES = FALSE),
      sum(
        dfIPM$status %in% "Confirmed IP non-starter" &
          dfIPM$consent_withdrawn %in% "Y"
      ),
      if (bHasPTD) {
        vapply(vDosed, n_status, integer(1), USE.NAMES = FALSE)
      } else {
        rep(NA, 4)
      }
    ),
    base = c(NA, rep("enrolled", 5), rep("dosed", 4))
  )
  nDenominator <- unname(c(enrolled = nEnrolled, dosed = nDosed)[stats$base])
  stats$pct <- ifelse(
    is.na(stats$n) | is.na(nDenominator) | nDenominator == 0,
    NA_real_,
    100 * stats$n / nDenominator
  )
  stats[c("label", "n", "pct", "base")]
}
