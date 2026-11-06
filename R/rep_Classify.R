#' Classify participants and measures for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Windows every measure of every enrolled participant once with the engine
#' behind [Detect_ConsecutiveRepeats()], the `kri0020` / `cou0020` metric
#' function, so every section of the report reads one frame. Summing `Numerator` and
#' `Denominator` by site or country reproduces the metrics.
#'
#' A participant's flag for a measure comes from [gsm.core::Flag()] with one of
#' two rules:
#' * `"count"` (default): repeating windows `Numerator` against
#'   `vFlagThresholds` (default Amber at 2, Red at 3 or more).
#' * `"rate"`: `Numerator / Denominator` against `vFlagThresholds` (default
#'   the site-level `kri0020` / `cou0020` `Threshold` in `dfMetrics`, else
#'   20\% / 30\%; see [rep_FlagThresholds()]).
#'
#' Amber is at or above the first threshold, Red at or above the second.
#' Participants with fewer than `nMinWindows` windows are `Not evaluable`.
#' Height, BSA and any other numeric `Mapped_VS` column are windowed and
#' flagged the same way, although they have no KRI. With `sysbp` and
#' `diabp`, paired blood pressure (`bp`, see [rep_Vitals()]) is added.
#'
#' @param lListings `list` with `Mapped_SUBJ` (enrolled participants with
#'   `subjid`, `invid` and `country`; a missing `invid` or `country` is
#'   shown as `"(missing)"`) and `Mapped_VS`.
#' @param dfMetrics `data.frame` Reporting metrics; the `kri0020*` rows supply
#'   the window length and the rate thresholds. Optional.
#' @param nWindowLength `numeric` Window length when `dfMetrics` has none.
#'   Default `NULL`, meaning 3. When `dfMetrics` has a window length, it wins
#'   and a different `nWindowLength` raises a warning.
#' @param strFlagRule `character` `"count"` or `"rate"`.
#' @param vFlagThresholds `numeric` Amber and Red thresholds: repeating
#'   windows for `"count"`, a proportion of windows for `"rate"`. Default
#'   `NULL`: see Details.
#' @param nMinWindows `numeric` Windows a participant needs for a flag.
#'   Default 1.
#'
#' @return A `list`:
#'   * `participants`: one row per participant and vital with `studyid`,
#'     `country`, `invid`, `subjid`, `vital`, `metric`, `n_records`
#'     (non-missing measurements), `Numerator`, `Denominator`, `rate` and
#'     `flag` (a factor with levels `Red`, `Amber`, `Green` and
#'     `Not evaluable`).
#'   * `measurements`: one row per non-missing measurement with `studyid`,
#'     `country`, `invid`, `subjid`, `record`, `visit`, `vs_dt`, `vital`,
#'     `value` (`NA` for paired BP), `value_text` (the displayed value),
#'     `seq`, `in_repeat_window` and `window_start` (the repeat-window
#'     marks used by [Detect_ConsecutiveRepeats()]).
#'   * `records`: the enrolled participants' `Mapped_VS` rows, with `country`
#'     and `invid` from `Mapped_SUBJ` and a `record` key that `measurements`
#'     refers to.
#'   * `vitals`: the rows of [rep_Vitals()] in the report, plus any other
#'     numeric `Mapped_VS` column.
#'   * `meta`: `window_length`, `window_source` (`"metrics"`, `"argument"` or
#'     `"default"`), `rule`, `thresholds` (Amber, Red), `min_windows` and
#'     `split_sites` (sites whose participants have more than one country;
#'     a warning lists them).
#' @keywords internal
#' @export
rep_Classify <- function(
  lListings,
  dfMetrics = NULL,
  nWindowLength = NULL,
  strFlagRule = c("count", "rate"),
  vFlagThresholds = NULL,
  nMinWindows = 1
) {
  strFlagRule <- match.arg(strFlagRule)
  vThresholds <- rep_FlagThresholds(strFlagRule, vFlagThresholds, dfMetrics)
  gsm.core::stop_if(
    cnd = !is.numeric(nMinWindows) || length(nMinWindows) != 1 || !is.finite(nMinWindows) ||
      nMinWindows < 1 || nMinWindows != round(nMinWindows),
    message = "nMinWindows must be a single whole number >= 1"
  )
  dfSubj <- lListings$Mapped_SUBJ
  vMissing <- setdiff(c("subjid", "invid", "country"), names(dfSubj))
  gsm.core::stop_if(
    cnd = is.null(dfSubj) || length(vMissing) > 0,
    message = paste0(
      "lListings$Mapped_SUBJ needs ",
      paste(vMissing, collapse = ", ")
    )
  )
  if (!"studyid" %in% names(dfSubj)) {
    dfSubj$studyid <- NA_character_
  }
  dfSubj <- dfSubj[!duplicated(dfSubj$subjid), c("studyid", "country", "invid", "subjid")]
  # A missing country or site becomes "(missing)" so the browser can filter it.
  for (strCol in c("country", "invid")) {
    dfSubj[[strCol]] <- as.character(dfSubj[[strCol]])
    dfSubj[[strCol]][is.na(dfSubj[[strCol]]) | dfSubj[[strCol]] == ""] <- "(missing)"
  }
  # Country comes from each participant (as in the cou0020 KRIs), so a site
  # whose participants carry different countries is counted in each of them.
  nCountries <- tapply(dfSubj$country, dfSubj$invid, function(x) length(unique(x)))
  vSplitSites <- as.character(names(nCountries)[nCountries > 1])
  if (length(vSplitSites) > 0) {
    gsm.core::LogMessage(
      level = "warn",
      message = "{length(vSplitSites)} site(s) have participants in more than one country: {paste(vSplitSites, collapse = ', ')}. Each participant counts toward their own country."
    )
  }

  dfVitals <- rep_Vitals()
  dfVS <- lListings$Mapped_VS
  vIDCols <- c("studyid", "subjid", "invid", "country", "visit", "vs_dt", "vsperf_std")
  vExtra <- if (is.null(dfVS)) {
    character(0)
  } else {
    setdiff(names(dfVS)[vapply(dfVS, is.numeric, logical(1))], c(dfVitals$vital, vIDCols))
  }
  # Paired BP: one value per record with both readings, so a run breaks when
  # either changes.
  if (!is.null(dfVS) && all(c("sysbp", "diabp") %in% names(dfVS))) {
    dfVS$bp <- ifelse(
      is.na(dfVS$sysbp) | is.na(dfVS$diabp),
      NA_character_,
      paste0(dfVS$sysbp, "/", dfVS$diabp)
    )
  }
  dfVitals <- dplyr::bind_rows(
    dfVitals[!is.na(dfVitals$metric) | dfVitals$vital %in% names(dfVS), ],
    tibble::tibble(vital = vExtra, label = vExtra, short = vExtra)
  )

  lWindow <- rep_WindowLength(dfMetrics, nWindowLength)
  nW <- lWindow$window_length

  # Mapped_SUBJ is the source of truth for site and country.
  if (!is.null(dfVS) && nrow(dfVS) > 0) {
    dfVS <- dfVS[dfVS$subjid %in% dfSubj$subjid, setdiff(names(dfVS), c("studyid", "invid", "country")), drop = FALSE]
    dfVS <- dplyr::left_join(dfVS, dfSubj, by = "subjid")
    dfVS$record <- seq_len(nrow(dfVS))
  }
  strOrderCol <- if ("visit" %in% names(dfVS)) "visit"
  # Each measure is windowed once; its marks feed the listings and its
  # Numerator and Denominator come from the summary step of
  # Detect_ConsecutiveRepeats(), the kri0020 metric function, so the report
  # reconciles with the KRI by construction.
  lWindowed <- lapply(
    dfVitals$vital[dfVitals$vital %in% names(dfVS)],
    function(strVital) {
      dfMarked <- MarkConsecutiveRepeats(
        dfVS,
        strVital,
        strOrderCol = strOrderCol,
        nWindowLength = nW
      )
      dfMetric <- SummarizeConsecutiveRepeats(dfMarked, unique(dfMarked$subjid), "subjid", nW)
      dfMetric$vital <- rep(strVital, nrow(dfMetric))
      x <- dfMarked[[strVital]]
      dfMeasurements <- tibble::tibble(
        studyid = dfMarked$studyid,
        country = dfMarked$country,
        invid = dfMarked$invid,
        subjid = dfMarked$subjid,
        record = dfMarked$record,
        visit = if (is.null(strOrderCol)) NA_character_ else as.character(dfMarked$visit),
        vs_dt = dfMarked$vs_dt,
        vital = rep(strVital, nrow(dfMarked)),
        value = if (is.character(x)) rep(NA_real_, length(x)) else as.numeric(x),
        value_text = if (is.character(x)) x else rep_FormatValue(as.numeric(x)),
        seq = dfMarked$seq,
        in_repeat_window = dfMarked$in_repeat_window,
        window_start = dfMarked$window_start
      )
      list(measurements = dfMeasurements, metric = dfMetric)
    }
  )
  dfMeasurements <- dplyr::bind_rows(lapply(lWindowed, `[[`, "measurements"))
  if (nrow(dfMeasurements) == 0) {
    dfMeasurements <- tibble::tibble(
      studyid = character(), country = character(), invid = character(),
      subjid = character(), record = integer(), visit = character(), vs_dt = as.Date(character()),
      vital = character(), value = numeric(), value_text = character(), seq = integer(),
      in_repeat_window = logical(), window_start = logical()
    )
  }

  dfCounts <- dfMeasurements %>%
    dplyr::group_by(.data$subjid, .data$vital) %>%
    dplyr::summarise(n_records = dplyr::n(), .groups = "drop")
  dfMetric <- dplyr::bind_rows(
    tibble::tibble(subjid = dfSubj$subjid[0], vital = character(), Numerator = numeric(), Denominator = numeric()),
    lapply(lWindowed, `[[`, "metric")
  )
  dfParticipants <- tidyr::crossing(
    dfSubj,
    tibble::tibble(vital = factor(dfVitals$vital, dfVitals$vital))
  ) %>%
    dplyr::mutate(vital = as.character(.data$vital)) %>%
    dplyr::left_join(dfCounts, by = c("subjid", "vital")) %>%
    dplyr::left_join(dfMetric, by = c("subjid", "vital")) %>%
    dplyr::mutate(
      metric = dfVitals$metric[match(.data$vital, dfVitals$vital)],
      n_records = as.numeric(dplyr::coalesce(.data$n_records, 0L)),
      Numerator = dplyr::coalesce(as.numeric(.data$Numerator), 0),
      Denominator = dplyr::coalesce(as.numeric(.data$Denominator), 0),
      rate = dplyr::if_else(
        .data$Denominator > 0,
        .data$Numerator / .data$Denominator,
        NA_real_
      )
    )
  # crossing() sorts; keep Mapped_SUBJ order, then the vital order.
  dfParticipants <- dfParticipants[order(
    match(dfParticipants$subjid, dfSubj$subjid),
    match(dfParticipants$vital, dfVitals$vital)
  ), ]

  vFlag <- rep_Flag(
    data.frame(
      GroupID = dfParticipants$subjid,
      Numerator = dfParticipants$Numerator,
      Denominator = dfParticipants$Denominator,
      Score = if (strFlagRule == "count") dfParticipants$Numerator else dfParticipants$rate
    ),
    vThresholds,
    nMinWindows
  )
  flag <- c("Green", "Amber", "Red")[vFlag + 1]
  flag[is.na(flag)] <- "Not evaluable"
  dfParticipants$flag <- factor(flag, levels = names(rep_FlagColors()))
  dfParticipants <- dfParticipants[c(
    "studyid", "country", "invid", "subjid", "vital", "metric",
    "n_records", "Numerator", "Denominator", "rate", "flag"
  )]
  rownames(dfParticipants) <- NULL

  list(
    participants = tibble::as_tibble(dfParticipants),
    measurements = dfMeasurements,
    records = if (is.null(dfVS)) NULL else tibble::as_tibble(dfVS),
    vitals = dfVitals,
    meta = c(lWindow, list(
      rule = strFlagRule, thresholds = vThresholds, min_windows = nMinWindows,
      split_sites = vSplitSites
    ))
  )
}
