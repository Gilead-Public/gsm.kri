#' Site flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One flag per site and vital. A KRI vital with `kri0020a`–`f` site results
#' takes the latest KRI flag (`source = "KRI"`). Every other
#' vital (height, BSA, paired BP, or a KRI vital without results) is flagged
#' in the report with the `kri0020` workflow steps (`source = "report"`):
#' [gsm.core::Input_Rate()], [gsm.core::Transform_Rate()],
#' [gsm.core::Analyze_Identity()] and [gsm.core::Flag()] on the participants'
#' windows, with the site rule of [rm_SiteRule()]. A site is not evaluated
#' (`flag` `NA`) without windows, below the accrual threshold or without a
#' KRI result.
#'
#' @param lClass `list` Output of [rm_Classify()].
#' @param dfResults `data.frame` Reporting results. Optional.
#' @param dfMetrics `data.frame` Reporting metrics. Optional.
#'
#' @return A `tibble` with `vital`, `country`, `invid`, `Numerator`,
#'   `Denominator`, `flag` (`0` Green, `1` Amber, `2` Red, `NA` not evaluated)
#'   and `source`, one row per vital and site with enrolled participants. A
#'   site whose participants have more than one country lists them in
#'   `country`, comma-separated.
#' @keywords internal
#' @export
rm_SiteFlagRows <- function(lClass, dfResults = NULL, dfMetrics = NULL) {
  lRule <- rm_SiteRule(dfMetrics)
  lKRI <- rm_SiteFlags(dfResults)
  df <- lClass$participants %>%
    dplyr::mutate(country = as.character(.data$country), invid = as.character(.data$invid)) %>%
    dplyr::group_by(.data$vital, .data$invid) %>%
    dplyr::summarise(
      country = paste(sort(unique(.data$country)), collapse = ", "),
      Numerator = sum(.data$Numerator),
      Denominator = sum(.data$Denominator),
      .groups = "drop"
    ) %>%
    dplyr::relocate("country", .before = "invid") %>%
    dplyr::arrange(match(.data$vital, lClass$vitals$vital), .data$invid)
  df$flag <- NA_integer_
  for (strVital in setdiff(unique(df$vital), names(lKRI))) {
    dfFlags <- rm_SiteFlagPipeline(lClass$participants[lClass$participants$vital == strVital, ], lRule)
    if (is.null(dfFlags)) next
    bRows <- df$vital == strVital
    df$flag[bRows] <- as.integer(dfFlags$Flag[match(df$invid[bRows], dfFlags$GroupID)])
  }
  df$source <- ifelse(df$vital %in% names(lKRI), "KRI", "report")
  for (strVital in intersect(names(lKRI), df$vital)) {
    bRows <- df$vital == strVital
    vFlag <- unlist(lKRI[[strVital]])[df$invid[bRows]]
    # kri0020 is one-sided; abs() guards against a two-sided Flag config.
    df$flag[bRows] <- abs(as.integer(unname(vFlag)))
  }
  df
}

# Site flags for one vital through the kri0020 workflow steps (Input_Rate,
# Transform_Rate, Analyze_Identity, Flag), using the participants' windows as
# the subject-level numerator and denominator. Returns `GroupID` (site) and
# `Flag`; a site without windows has no row. NULL when no participant has a
# window, which Input_Rate() rejects.
rm_SiteFlagPipeline <- function(dfParticipants, lRule) {
  if (!nrow(dfParticipants) || sum(dfParticipants$Denominator) == 0) {
    return(NULL)
  }
  dfAnalyzed <- rm_Quietly(gsm.core::Input_Rate(
    dfSubjects = dfParticipants,
    dfNumerator = dfParticipants,
    dfDenominator = dfParticipants,
    strSubjectCol = "subjid",
    strGroupCol = "invid",
    strGroupLevel = "Site",
    strNumeratorMethod = "Sum",
    strDenominatorMethod = "Sum",
    strNumeratorCol = "Numerator",
    strDenominatorCol = "Denominator"
  ) %>%
    gsm.core::Transform_Rate() %>%
    gsm.core::Analyze_Identity())
  dfAnalyzed$Flag <- rm_Flag(dfAnalyzed, lRule$thresholds, lRule$accrual)
  dfAnalyzed[c("GroupID", "Flag")]
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
