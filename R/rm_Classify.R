#' Vital signs known to the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The six vitals scored by `kri0020a`–`f` / `cou0020a`–`f`, paired blood
#' pressure, then height and BSA. Every vital is flagged the same way; only
#' the six have a KRI.
#'
#' Paired blood pressure (`bp`) is report-only: one value per visit record
#' with both systolic and diastolic BP, so a window repeats only when both
#' repeat over the same visits. It has no metric and does not reconcile with
#' `kri0020c` / `kri0020d`.
#'
#' @return A `tibble` with `vital` (the `Mapped_VS` column), `label`, `short`
#'   and `metric` (the site workflow ID; `NA` without a KRI).
#' @keywords internal
#' @export
rm_Vitals <- function() {
  tibble::tibble(
    vital = c("weight", "pulse", "sysbp", "diabp", "bp", "resp", "temp", "height", "bsa"),
    label = c(
      "Weight", "Heart rate", "Systolic BP", "Diastolic BP", "Blood pressure (SBP/DBP)",
      "Respiratory rate", "Temperature", "Height", "BSA"
    ),
    short = c("WT", "HR", "SBP", "DBP", "BP", "RR", "Temp", "Ht", "BSA"),
    metric = c(paste0("kri0020", letters[1:4]), NA, paste0("kri0020", letters[5:6]), NA, NA)
  )
}

#' Flag colors for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' @return A named `character` vector of hex colors, in severity order.
#' @keywords internal
#' @export
rm_FlagColors <- function() {
  c(
    Red = "#FF5859",
    Amber = "#FEAA02",
    Green = "#3DAF06",
    "Not evaluable" = "#CACACA"
  )
}

#' Classify participants and vitals for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Windows every vital of every enrolled participant once, with the same
#' logic as the `kri0020` / `cou0020` metrics, so every section of the report
#' reads one frame. Summing `Numerator` and `Denominator` by site or country
#' reproduces the metrics.
#'
#' A participant's flag for a vital uses one of two rules:
#' * `"count"` (default): repeating windows `Numerator` against
#'   `vFlagThresholds` (default Amber at 2, Red at 3 or more).
#' * `"rate"`: `Numerator / Denominator` against `vFlagThresholds` (default
#'   the `kri0020` `Threshold` in `dfMetrics`, else 20\% / 30\%).
#'
#' Amber is at or above the first threshold, Red at or above the second.
#' Participants with fewer than `nMinWindows` windows are `Not evaluable`.
#' Height, BSA and any other numeric `Mapped_VS` column are windowed and
#' flagged the same way, although they have no KRI. With `sysbp` and
#' `diabp`, paired blood pressure (`bp`, see [rm_Vitals()]) is added.
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
#'     `flag` (a factor with the levels of [rm_FlagColors()]).
#'   * `measurements`: one row per non-missing measurement with `studyid`,
#'     `country`, `invid`, `subjid`, `record`, `visit`, `vs_dt`, `vital`,
#'     `value` (`NA` for paired BP), `value_text` (the displayed value),
#'     `seq`, `in_repeat_window` and `window_start` (see
#'     [Mark_ConsecutiveRepeats()]).
#'   * `records`: the enrolled participants' `Mapped_VS` rows, with `country`
#'     and `invid` from `Mapped_SUBJ` and a `record` key that `measurements`
#'     refers to.
#'   * `vitals`: the rows of [rm_Vitals()] in the report, plus any other
#'     numeric `Mapped_VS` column.
#'   * `meta`: `window_length`, `window_source` (`"metrics"`, `"argument"` or
#'     `"default"`), `rule`, `thresholds` (Amber, Red) and `min_windows`.
#' @keywords internal
#' @export
rm_Classify <- function(
  lListings,
  dfMetrics = NULL,
  nWindowLength = NULL,
  strFlagRule = c("count", "rate"),
  vFlagThresholds = NULL,
  nMinWindows = 1
) {
  strFlagRule <- match.arg(strFlagRule)
  vThresholds <- rm_FlagThresholds(strFlagRule, vFlagThresholds, dfMetrics)
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

  dfVitals <- rm_Vitals()
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

  lWindow <- rm_WindowLength(dfMetrics, nWindowLength)
  nW <- lWindow$window_length

  # Mapped_SUBJ is the source of truth for site and country.
  if (!is.null(dfVS) && nrow(dfVS) > 0) {
    dfVS <- dfVS[dfVS$subjid %in% dfSubj$subjid, setdiff(names(dfVS), c("studyid", "invid", "country")), drop = FALSE]
    dfVS <- dplyr::left_join(dfVS, dfSubj, by = "subjid")
    dfVS$record <- seq_len(nrow(dfVS))
  }
  strOrderCol <- if ("visit" %in% names(dfVS)) "visit"
  dfMeasurements <- dplyr::bind_rows(lapply(
    dfVitals$vital[dfVitals$vital %in% names(dfVS)],
    function(strVital) {
      dfMarked <- Mark_ConsecutiveRepeats(
        dfVS,
        strVital,
        strOrderCol = strOrderCol,
        nWindowLength = nW
      )
      x <- dfMarked[[strVital]]
      tibble::tibble(
        studyid = dfMarked$studyid,
        country = dfMarked$country,
        invid = dfMarked$invid,
        subjid = dfMarked$subjid,
        record = dfMarked$record,
        visit = if (is.null(strOrderCol)) NA_character_ else as.character(dfMarked$visit),
        vs_dt = dfMarked$vs_dt,
        vital = rep(strVital, nrow(dfMarked)),
        value = if (is.character(x)) rep(NA_real_, length(x)) else as.numeric(x),
        value_text = if (is.character(x)) x else format_value(as.numeric(x)),
        seq = dfMarked$seq,
        in_repeat_window = dfMarked$in_repeat_window,
        window_start = dfMarked$window_start
      )
    }
  ))
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
    dplyr::summarise(
      n_records = dplyr::n(),
      Numerator = sum(.data$window_start),
      .groups = "drop"
    )
  dfParticipants <- tidyr::crossing(
    dfSubj,
    tibble::tibble(vital = factor(dfVitals$vital, dfVitals$vital))
  ) %>%
    dplyr::mutate(vital = as.character(.data$vital)) %>%
    dplyr::left_join(dfCounts, by = c("subjid", "vital")) %>%
    dplyr::mutate(
      metric = dfVitals$metric[match(.data$vital, dfVitals$vital)],
      n_records = as.numeric(dplyr::coalesce(.data$n_records, 0L)),
      Numerator = as.numeric(dplyr::coalesce(.data$Numerator, 0L)),
      Denominator = pmax(0, .data$n_records - nW + 1),
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

  vScore <- if (strFlagRule == "count") dfParticipants$Numerator else dfParticipants$rate
  flag <- dplyr::case_when(
    dfParticipants$Denominator < nMinWindows ~ "Not evaluable",
    vScore >= vThresholds[2] ~ "Red",
    vScore >= vThresholds[1] ~ "Amber",
    TRUE ~ "Green"
  )
  dfParticipants$flag <- factor(flag, levels = names(rm_FlagColors()))
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
    meta = c(lWindow, list(rule = strFlagRule, thresholds = vThresholds, min_windows = nMinWindows))
  )
}

#' Repeat Measurements participant flag thresholds
#'
#' Amber and Red thresholds for a participant flag rule. Count thresholds
#' default to 2 and 3 repeating windows. Rate thresholds default to the
#' `kri0020` metric thresholds so that the participant flag matches the site
#' KRI, or 0.2 and 0.3 without them.
#'
#' @param strFlagRule `character` `"count"` (repeating windows) or `"rate"`
#'   (share of windows that repeat).
#' @param vFlagThresholds `numeric` Amber then Red threshold, or `NULL` for
#'   the defaults. Rates are fractions.
#' @param dfMetrics `data.frame` Metric metadata with `ID` and `Threshold`.
#'
#' @return A `numeric` vector: Amber, then Red.
#'
#' @keywords internal
#' @export
rm_FlagThresholds <- function(strFlagRule = c("count", "rate"), vFlagThresholds = NULL, dfMetrics = NULL) {
  strFlagRule <- match.arg(strFlagRule)
  if (is.null(vFlagThresholds)) {
    if (strFlagRule == "count") {
      return(c(2, 3))
    }
    vMetric <- if (!is.null(dfMetrics$Threshold) && !is.null(dfMetrics$ID)) {
      unique(stats::na.omit(as.character(dfMetrics$Threshold[grepl("^kri0020", dfMetrics$ID)])))
    }
    if (!length(vMetric)) {
      return(c(0.2, 0.3))
    }
    if (length(vMetric) > 1) {
      cli::cli_warn("The kri0020 metrics use different thresholds; the report uses {vMetric[1]}.")
    }
    vFlagThresholds <- as.numeric(strsplit(vMetric[1], ",")[[1]])
  }
  gsm.core::stop_if(
    cnd = !is.numeric(vFlagThresholds) || length(vFlagThresholds) != 2 ||
      any(!is.finite(vFlagThresholds)) || any(vFlagThresholds < 0) ||
      vFlagThresholds[1] > vFlagThresholds[2],
    message = "vFlagThresholds must be two non-negative numbers, Amber then Red, with Amber <= Red"
  )
  as.numeric(vFlagThresholds)
}

# D4: the metric's window length wins so the report reconciles with the KRI.
rm_WindowLength <- function(dfMetrics, nWindowLength = NULL) {
  vMetricW <- if (!is.null(dfMetrics$WindowLength)) {
    stats::na.omit(as.numeric(dfMetrics$WindowLength[grepl("^(kri|cou)0020", dfMetrics$ID)]))
  }
  if (length(vMetricW)) {
    nMetricW <- vMetricW[1]
    if (length(unique(vMetricW)) > 1) {
      cli::cli_warn(
        "The kri0020/cou0020 metrics use different window lengths; the report uses {nMetricW}."
      )
    }
    if (!is.null(nWindowLength) && !isTRUE(nWindowLength == nMetricW)) {
      cli::cli_warn(c(
        "{.arg nWindowLength} ({nWindowLength}) differs from the kri0020 metrics ({nMetricW}).",
        i = "The report uses {nMetricW} so it reconciles with the metrics."
      ))
    }
    return(list(window_length = nMetricW, window_source = "metrics"))
  }
  if (!is.null(nWindowLength)) {
    return(list(window_length = nWindowLength, window_source = "argument"))
  }
  list(window_length = 3, window_source = "default")
}
