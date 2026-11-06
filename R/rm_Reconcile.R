#' Reconcile the Repeat Measurements report with the kri0020 metrics
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Sums participant numerators and denominators per KRI vital and compares
#' them with the site-level `kri0020a`–`f` results of the latest snapshot.
#'
#' @param dfParticipants `data.frame` `participants` from [rm_Classify()].
#' @param dfResults `data.frame` Reporting results.
#'
#' @return A `tibble` with `vital`, `metric`, `Numerator`, `Denominator`,
#'   `kri_Numerator`, `kri_Denominator` and `match`, one row per KRI vital
#'   with results; `NULL` when `dfResults` has no `kri0020` results.
#' @keywords internal
#' @export
rm_Reconcile <- function(dfParticipants, dfResults) {
  if (is.null(dfResults) || !all(c("MetricID", "Numerator", "Denominator") %in% names(dfResults))) {
    return(NULL)
  }
  dfKRI <- dfResults[grepl("^Analysis_kri0020[a-f]$", dfResults$MetricID), ]
  if ("SnapshotDate" %in% names(dfKRI) && nrow(dfKRI) > 0) {
    dfKRI <- dfKRI[as.Date(dfKRI$SnapshotDate) == max(as.Date(dfKRI$SnapshotDate)), ]
  }
  if (nrow(dfKRI) == 0) {
    return(NULL)
  }
  dfKRI <- dfKRI %>%
    dplyr::mutate(metric = sub("^Analysis_", "", .data$MetricID)) %>%
    dplyr::group_by(.data$metric) %>%
    dplyr::summarise(
      kri_Numerator = sum(.data$Numerator, na.rm = TRUE),
      kri_Denominator = sum(.data$Denominator, na.rm = TRUE),
      .groups = "drop"
    )
  dfParticipants[!is.na(dfParticipants$metric), ] %>%
    dplyr::group_by(.data$vital, .data$metric) %>%
    dplyr::summarise(
      Numerator = sum(.data$Numerator),
      Denominator = sum(.data$Denominator),
      .groups = "drop"
    ) %>%
    dplyr::inner_join(dfKRI, by = "metric") %>%
    dplyr::mutate(
      match = .data$Numerator == .data$kri_Numerator &
        .data$Denominator == .data$kri_Denominator
    ) %>%
    dplyr::arrange(match(.data$vital, rm_Vitals()$vital))
}
