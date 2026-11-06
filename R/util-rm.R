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
#' @noRd
rm_FlagColors <- function() {
  c(
    Red = "#FF5859",
    Amber = "#FEAA02",
    Green = "#3DAF06",
    "Not evaluable" = "#CACACA"
  )
}

# Severity of each flag (Red 3, Amber 2, Green 1, Not evaluable 0), the one
# sort key every participant ordering uses.
rm_FlagSeverity <- function(vFlag) {
  vSeverity <- c(Red = 3L, Amber = 2L, Green = 1L, `Not evaluable` = 0L)
  unname(vSeverity[as.character(vFlag)])
}

#' Repeat Measurements participant flag thresholds
#'
#' @description
#' `r lifecycle::badge("experimental")`
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

# Flags `Score` with gsm.core::Flag(), as the kri0020 workflow does: 0 below
# Amber, 1 from Amber, 2 from Red, NA for a missing score or a `Denominator`
# below `nAccrual`. `df` needs `GroupID`, `Numerator`, `Denominator` and
# `Score`. Returns the flags in row order.
rm_Flag <- function(df, vThresholds, nAccrual) {
  vFlag <- c(0, 1, 2)
  # Flag() cuts at the thresholds, which must differ; equal ones leave no Amber.
  if (vThresholds[1] == vThresholds[2]) {
    vThresholds <- vThresholds[2]
    vFlag <- c(0, 2)
  }
  rm_Quietly(gsm.core::Flag(
    df,
    strColumn = "Score",
    vThreshold = vThresholds,
    vFlag = vFlag,
    vFlagOrder = NULL,
    nAccrualThreshold = nAccrual,
    strAccrualMetric = "Denominator"
  ))$Flag
}

# Mutes the gsm.core step logs, which would otherwise print once per vital
# while the report renders, and the expected warning that sites without
# windows are dropped. Other warnings still surface.
rm_Quietly <- function(expr) {
  withCallingHandlers(
    expr,
    message = function(m) invokeRestart("muffleMessage"),
    warning = function(w) {
      if (grepl("value of 0 removed", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

# The metric's window length wins so the report reconciles with the KRI.
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

# DT CSV button exporting the rows the filters show; `columns` is a DT
# column selector.
# lHeaders: CSV headers by 0-based column index where the CSV should not use
# the displayed header, such as an abbreviation.
rm_CsvButton <- function(bExport, strFile, columns = ":visible", lHeaders = NULL) {
  if (!isTRUE(bExport)) {
    return(list())
  }
  lOptions <- list(
    columns = columns,
    orthogonal = "export",
    modifier = list(search = "applied")
  )
  if (length(lHeaders)) {
    lOptions$format <- list(header = DT::JS(sprintf(
      "function (data, idx) { var h = %s; return h[idx] !== undefined ? h[idx] : data; }",
      jsonlite::toJSON(lHeaders, auto_unbox = TRUE)
    )))
  }
  list(list(
    extend = "csv",
    text = "Download CSV",
    filename = strFile,
    exportOptions = lOptions
  ))
}

rm_FormatValue <- function(x) {
  format(x, trim = TRUE, drop0trailing = TRUE, scientific = FALSE, digits = 10)
}
