#' IP Compliance overview figures
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The nine study-wide overview figures in report order. Non-starter figures
#' are shares of enrolled participants; Ongoing, Study complete and Premature
#' treatment discontinuation are shares of dosed participants.
#'
#' @param dfIPC `data.frame` Output of [ipc_ClassifyParticipants()].
#' @param bHasPTD `logical` Whether premature treatment discontinuation data
#'   was delivered. When `FALSE`, that figure is `NA`.
#'
#' @return A `tibble` with `label`, `n`, `pct` (`NA` for a zero denominator)
#'   and `base` (`"enrolled"`, `"dosed"`, or `NA` for Total enrolled).
#' @keywords internal
#' @export
ipc_OverviewStats <- function(dfIPC, bHasPTD) {
  vLabels <- names(ipc_StatusColors())
  nEnrolled <- nrow(dfIPC)
  nDosed <- sum(dfIPC$dosed %in% "Y")
  n_status <- function(i) sum(dfIPC$status %in% vLabels[i])
  stats <- tibble::tibble(
    label = c(
      "Total enrolled",
      "Confirmed dosed",
      vLabels[2:4],
      "Confirmed with consent withdrawn",
      "Ongoing",
      "Study complete",
      "Premature treatment discontinuation"
    ),
    n = c(
      nEnrolled,
      nDosed,
      n_status(2),
      n_status(3),
      n_status(4),
      sum(dfIPC$status %in% vLabels[4] & dfIPC$consent_withdrawn %in% "Y"),
      n_status(7),
      n_status(1),
      if (bHasPTD) n_status(5) else NA
    ),
    base = c(NA, rep("enrolled", 5), rep("dosed", 3))
  )
  nDenominator <- unname(c(enrolled = nEnrolled, dosed = nDosed)[stats$base])
  stats$pct <- ifelse(
    is.na(stats$n) | is.na(nDenominator) | nDenominator == 0,
    NA_real_,
    100 * stats$n / nDenominator
  )
  stats[c("label", "n", "pct", "base")]
}
