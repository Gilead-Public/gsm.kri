#' Site flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One flag per site and measure. A KRI measure with `kri0020a`–`f` site results
#' takes the latest KRI flag (`source = "KRI"`). Every other
#' measure (height, BSA, paired BP, or a KRI measure without results) is flagged
#' in the report with the `kri0020` workflow steps (`source = "report"`):
#' [gsm.core::Input_Rate()], [gsm.core::Transform_Rate()],
#' [gsm.core::Analyze_Identity()] and [gsm.core::Flag()] on the participants'
#' windows, with the site rule of [rep_SiteRule()]. A site is not evaluated
#' (`flag` `NA`) without windows, below the accrual threshold or without a
#' KRI result.
#'
#' @param lClass `list` Output of [rep_Classify()].
#' @param dfResults `data.frame` Reporting results. Optional.
#' @param dfMetrics `data.frame` Reporting metrics. Optional.
#'
#' @return A `tibble` with `vital`, `country`, `invid`, `Numerator`,
#'   `Denominator`, `flag` (`0` Green, `1` Amber, `2` Red, `NA` not evaluated)
#'   and `source`, one row per measure and site with enrolled participants. A
#'   site whose participants have more than one country lists them in
#'   `country`, comma-separated.
#' @keywords internal
#' @export
rep_SiteFlagRows <- function(lClass, dfResults = NULL, dfMetrics = NULL) {
  lRule <- rep_SiteRule(dfMetrics)
  lKRI <- rep_SiteFlags(dfResults)
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
    dfFlags <- rep_SiteFlagPipeline(lClass$participants[lClass$participants$vital == strVital, ], lRule)
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
rep_SiteFlagPipeline <- function(dfParticipants, lRule) {
  if (!nrow(dfParticipants) || sum(dfParticipants$Denominator) == 0) {
    return(NULL)
  }
  dfAnalyzed <- rep_Quietly(gsm.core::Input_Rate(
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
  dfAnalyzed$Flag <- rep_Flag(dfAnalyzed, lRule$thresholds, lRule$accrual)
  dfAnalyzed[c("GroupID", "Flag")]
}

#' Site flag rule for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The `kri0020` / `cou0020` site rule: Amber and Red at the metric `Threshold` (default
#' 20\% and 30\% of windows repeat) for sites with at least the metric
#' `AccrualThreshold` windows (default 3).
#'
#' @param dfMetrics `data.frame` Reporting metrics. Optional.
#'
#' @return A `list` with `thresholds` (Amber, Red; fractions) and `accrual`.
#' @keywords internal
#' @export
rep_SiteRule <- function(dfMetrics = NULL) {
  nAccrual <- rep_MetricMeta(dfMetrics, "AccrualThreshold")
  list(
    thresholds = rep_FlagThresholds("rate", dfMetrics = dfMetrics),
    accrual = if (is.null(nAccrual)) 3 else as.numeric(nAccrual)
  )
}

#' Site KRI flags for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The site-level `kri0020a`–`f` flags from each metric's latest snapshot,
#' keyed by measure (`vital`). A site without a flag in that snapshot is `NA` (not
#' evaluated).
#'
#' @param dfResults `data.frame` Reporting results.
#'
#' @return A named `list` (measure to a named list of site flags); empty when
#'   `dfResults` has no `kri0020` site results.
#' @noRd
rep_SiteFlags <- function(dfResults) {
  vNeeded <- c("MetricID", "GroupLevel", "GroupID", "Flag")
  if (is.null(dfResults) || !all(vNeeded %in% names(dfResults))) {
    return(stats::setNames(list(), character(0)))
  }
  df <- dfResults[grepl("^Analysis_kri0020[a-f]$", dfResults$MetricID) &
    dfResults$GroupLevel %in% "Site", ]
  # Pick each metric's latest snapshot before reading flags, so a missing
  # latest flag stays not evaluated instead of reviving an older one.
  if ("SnapshotDate" %in% names(df) && nrow(df) > 0) {
    vDate <- as.Date(df$SnapshotDate)
    bLatest <- vDate == stats::ave(vDate, df$MetricID, FUN = function(x) max(x, na.rm = TRUE))
    df <- df[bLatest %in% TRUE, ]
  }
  dfVitals <- rep_Vitals()
  df$vital <- dfVitals$vital[match(sub("^Analysis_", "", df$MetricID), dfVitals$metric)]
  lapply(split(df, df$vital), function(d) {
    as.list(stats::setNames(as.integer(d$Flag), as.character(d$GroupID)))
  })
}
