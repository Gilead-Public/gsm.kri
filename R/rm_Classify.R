#' Vital signs known to the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The six vitals scored by `kri0020a`–`f` / `cou0020a`–`f`, then height and
#' BSA, which are listed without a flag.
#'
#' @return A `tibble` with `vital` (the `Mapped_VS` column), `label`, `short`,
#'   `group` (the report's vital filter; `NA` without a KRI) and `metric`
#'   (the site workflow ID; `NA` without a KRI).
#' @keywords internal
#' @export
rm_Vitals <- function() {
  tibble::tibble(
    vital = c("weight", "pulse", "sysbp", "diabp", "resp", "temp", "height", "bsa"),
    label = c(
      "Weight", "Heart rate", "Systolic BP", "Diastolic BP",
      "Respiratory rate", "Temperature", "Height", "BSA"
    ),
    short = c("WT", "HR", "SBP", "DBP", "RR", "Temp", "Ht", "BSA"),
    group = c("Weight", "HR", "BP", "BP", "RR", "Temp", NA, NA),
    metric = c(paste0("kri0020", letters[1:6]), NA, NA)
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
    "Not evaluable" = "#CACACA",
    "No KRI" = "#FFFFFF"
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
#' A participant's flag for a KRI vital uses one of two rules:
#' * `"rate"` (default): `Numerator / Denominator` against the vital's site
#'   metric thresholds (`kri0020a`–`f` `Threshold` in `dfMetrics`, else 20\% /
#'   30\%): Amber at or above the first, Red at or above the second.
#' * `"count"`: Amber at 1 repeat window, Red at 2 or more.
#'
#' Participants with no evaluable window (`Denominator` 0) are
#' `Not evaluable`. Height, BSA and any other numeric `Mapped_VS` column are
#' windowed the same way and flagged `No KRI`.
#'
#' @param lListings `list` with `Mapped_SUBJ` (enrolled participants with
#'   `subjid`, `invid` and `country`) and `Mapped_VS`.
#' @param dfMetrics `data.frame` Reporting metrics; the `kri0020*` rows supply
#'   the window length and thresholds. Optional.
#' @param nWindowLength `numeric` Window length when `dfMetrics` has none.
#'   Default `NULL`, meaning 3. When `dfMetrics` has a window length, it wins
#'   and a different `nWindowLength` raises a warning.
#' @param strFlagRule `character` `"rate"` or `"count"`.
#'
#' @return A `list`:
#'   * `participants`: one row per participant and vital with `studyid`,
#'     `country`, `invid`, `subjid`, `vital`, `metric`, `n_records`
#'     (non-missing measurements), `Numerator`, `Denominator`, `rate` and
#'     `flag` (a factor with the levels of [rm_FlagColors()]).
#'   * `measurements`: one row per non-missing measurement with `studyid`,
#'     `country`, `invid`, `subjid`, `record`, `visit`, `vs_dt`, `vital`,
#'     `value`, `seq`, `in_repeat_window` and `window_start` (see
#'     [Mark_ConsecutiveRepeats()]).
#'   * `records`: the enrolled participants' `Mapped_VS` rows, with `country`
#'     and `invid` from `Mapped_SUBJ` and a `record` key that `measurements`
#'     refers to.
#'   * `vitals`: the rows of [rm_Vitals()] in the report, plus any other
#'     numeric `Mapped_VS` column.
#'   * `meta`: `window_length`, `window_source` (`"metrics"`, `"argument"` or
#'     `"default"`), `rule` and `thresholds` (per KRI vital).
#' @keywords internal
#' @export
rm_Classify <- function(
  lListings,
  dfMetrics = NULL,
  nWindowLength = NULL,
  strFlagRule = c("rate", "count")
) {
  strFlagRule <- match.arg(strFlagRule)
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

  dfVitals <- rm_Vitals()
  dfVS <- lListings$Mapped_VS
  vIDCols <- c("studyid", "subjid", "invid", "country", "visit", "vs_dt", "vsperf_std")
  vExtra <- if (is.null(dfVS)) {
    character(0)
  } else {
    setdiff(names(dfVS)[vapply(dfVS, is.numeric, logical(1))], c(dfVitals$vital, vIDCols))
  }
  dfVitals <- dplyr::bind_rows(
    dfVitals[!is.na(dfVitals$metric) | dfVitals$vital %in% names(dfVS), ],
    tibble::tibble(vital = vExtra, label = vExtra, short = vExtra)
  )

  lWindow <- rm_WindowLength(dfMetrics, nWindowLength)
  nW <- lWindow$window_length
  lThresholds <- stats::setNames(
    lapply(dfVitals$metric[!is.na(dfVitals$metric)], function(id) {
      strThreshold <- if (!is.null(dfMetrics$Threshold)) {
        dfMetrics$Threshold[dfMetrics$ID %in% id]
      }
      if (length(strThreshold) && !is.na(strThreshold[1])) {
        as.numeric(strsplit(strThreshold[1], ",")[[1]])
      } else {
        c(0.2, 0.3)
      }
    }),
    dfVitals$vital[!is.na(dfVitals$metric)]
  )

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
      tibble::tibble(
        studyid = dfMarked$studyid,
        country = dfMarked$country,
        invid = dfMarked$invid,
        subjid = dfMarked$subjid,
        record = dfMarked$record,
        visit = if (is.null(strOrderCol)) NA_character_ else as.character(dfMarked$visit),
        vs_dt = dfMarked$vs_dt,
        vital = rep(strVital, nrow(dfMarked)),
        value = as.numeric(dfMarked[[strVital]]),
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
      vital = character(), value = numeric(), seq = integer(),
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

  vLow <- vapply(dfParticipants$vital, function(v) c(lThresholds[[v]], NA)[1], numeric(1))
  vHigh <- vapply(dfParticipants$vital, function(v) c(lThresholds[[v]], NA, NA)[2], numeric(1))
  bRed <- if (strFlagRule == "count") dfParticipants$Numerator >= 2 else dfParticipants$rate >= vHigh
  bAmber <- if (strFlagRule == "count") dfParticipants$Numerator >= 1 else dfParticipants$rate >= vLow
  flag <- dplyr::case_when(
    is.na(dfParticipants$metric) ~ "No KRI",
    dfParticipants$Denominator == 0 ~ "Not evaluable",
    bRed ~ "Red",
    bAmber ~ "Amber",
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
    meta = c(lWindow, list(rule = strFlagRule, thresholds = lThresholds))
  )
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
