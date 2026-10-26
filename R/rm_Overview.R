#' Study overview rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per vital for the whole study, whatever the report's filters:
#' sites evaluated and flagged (see [rm_SiteFlagRows()]) and participants
#' evaluable and flagged. A participant is evaluable for a vital when their
#' flag is Red, Amber or Green. The report's filter script computes the
#' participant counts in the browser so that they follow the reviewer's flag
#' settings.
#'
#' @param lClass `list` Output of [rm_Classify()].
#' @param dfSites `data.frame` Output of [rm_SiteFlagRows()].
#'
#' @return A `tibble` in vital order with `vital`, `label`, `metric`,
#'   `site_source` (`"KRI"` or `"report"`), `sites`, `sites_evaluated`,
#'   `site_amber`, `site_red`, `enrolled`, `evaluable`, `amber` and `red`.
#' @keywords internal
#' @export
rm_OverviewRows <- function(lClass, dfSites = rm_SiteFlagRows(lClass)) {
  dfVitals <- lClass$vitals
  dfP <- lClass$participants %>%
    dplyr::group_by(.data$vital) %>%
    dplyr::summarise(
      enrolled = dplyr::n_distinct(.data$subjid),
      evaluable = sum(.data$flag %in% c("Red", "Amber", "Green")),
      amber = sum(.data$flag == "Amber"),
      red = sum(.data$flag == "Red"),
      .groups = "drop"
    )
  dfS <- dfSites %>%
    dplyr::group_by(.data$vital) %>%
    dplyr::summarise(
      site_source = dplyr::first(.data$source),
      sites = dplyr::n_distinct(.data$invid),
      sites_evaluated = sum(!is.na(.data$flag)),
      site_amber = sum(.data$flag %in% 1L),
      site_red = sum(.data$flag %in% 2L),
      .groups = "drop"
    )
  dfVitals[c("vital", "label", "metric")] %>%
    dplyr::inner_join(dfS, by = "vital") %>%
    dplyr::inner_join(dfP, by = "vital") %>%
    dplyr::mutate(dplyr::across(
      c("sites", "sites_evaluated", "site_amber", "site_red", "enrolled", "evaluable", "amber", "red"),
      as.integer
    ))
}

#' Site flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One flag per site and vital. A KRI vital with `kri0020a`–`f` site results
#' takes the latest KRI flag ([rm_SiteFlags()]; `source = "KRI"`). Every other
#' vital (height, BSA, paired BP, or a KRI vital without results) is flagged
#' in the report like the KRI (`source = "report"`): the site's repeating
#' windows over its windows (summed over its participants) against the site
#' rule of [rm_SiteRule()]. A site is not evaluated (`flag` `NA`) below the
#' accrual threshold or without a KRI result.
#'
#' @param lClass `list` Output of [rm_Classify()].
#' @param dfResults `data.frame` Reporting results. Optional.
#' @param dfMetrics `data.frame` Reporting metrics. Optional.
#'
#' @return A `tibble` with `vital`, `country`, `invid`, `Numerator`,
#'   `Denominator`, `flag` (`0` Green, `1` Amber, `2` Red, `NA` not evaluated)
#'   and `source`, one row per vital and site with enrolled participants.
#' @keywords internal
#' @export
rm_SiteFlagRows <- function(lClass, dfResults = NULL, dfMetrics = NULL) {
  lRule <- rm_SiteRule(dfMetrics)
  lKRI <- rm_SiteFlags(dfResults)
  df <- lClass$participants %>%
    dplyr::mutate(country = as.character(.data$country), invid = as.character(.data$invid)) %>%
    dplyr::group_by(.data$vital, .data$country, .data$invid) %>%
    dplyr::summarise(
      Numerator = sum(.data$Numerator),
      Denominator = sum(.data$Denominator),
      .groups = "drop"
    ) %>%
    dplyr::arrange(match(.data$vital, lClass$vitals$vital), .data$invid)
  vRate <- ifelse(df$Denominator > 0, df$Numerator / df$Denominator, NA_real_)
  df$flag <- dplyr::case_when(
    df$Denominator < lRule$accrual ~ NA_integer_,
    vRate >= lRule$thresholds[2] ~ 2L,
    vRate >= lRule$thresholds[1] ~ 1L,
    TRUE ~ 0L
  )
  df$source <- ifelse(df$vital %in% names(lKRI), "KRI", "report")
  for (strVital in intersect(names(lKRI), df$vital)) {
    bRows <- df$vital == strVital
    vFlag <- unlist(lKRI[[strVital]])[df$invid[bRows]]
    df$flag[bRows] <- abs(as.integer(unname(vFlag)))
  }
  df
}

#' Site flag rule for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The `kri0020` site rule: Amber and Red at the metric `Threshold` (default
#' 20\% and 30\% of windows repeat) for sites with at least the metric
#' `AccrualThreshold` windows (default 3).
#'
#' @param dfMetrics `data.frame` Reporting metrics. Optional.
#'
#' @return A `list` with `thresholds` (Amber, Red; fractions) and `accrual`.
#' @keywords internal
#' @export
rm_SiteRule <- function(dfMetrics = NULL) {
  nAccrual <- if (!is.null(dfMetrics$AccrualThreshold) && !is.null(dfMetrics$ID)) {
    unique(stats::na.omit(as.numeric(dfMetrics$AccrualThreshold[grepl("^kri0020", dfMetrics$ID)])))
  }
  list(
    thresholds = rm_FlagThresholds("rate", dfMetrics = dfMetrics),
    accrual = if (length(nAccrual)) nAccrual[1] else 3
  )
}

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
