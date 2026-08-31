#' Generate Record Duplication Report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Convenience function that runs [Detect_ConsecutiveRepeats()] across multiple measures
#' and produces a [Widget_RecordDuplication()] htmlwidget. Supports both wide-format
#' vitals data and long-format lab data.
#'
#' The report uses the same rolling-window detection as the [Count_Duplicates()] metric
#' workflow, so a run highlighted here is exactly a run that contributes repeat windows to
#' the metric.
#'
#' @param dfMappedVS `data.frame` Optional. Wide-format vitals data with measurement
#'   columns (e.g., weight, sysbp, diabp).
#' @param dfMappedLB `data.frame` Optional. Long-format lab data with measure identifier
#'   and numeric result columns.
#' @param dfMappedSUBJ `data.frame` Subject-level data with `subjid` and group columns.
#' @param vMeasuresVS `character` Vital sign columns to analyze. Default: all numeric
#'   columns in `dfMappedVS` except identifiers.
#' @param vMeasuresLB `character` Lab test names to analyze. Default: all unique values
#'   in `lbtstnam` column.
#' @param vPrioritizedMeasures `character` Measures with KRI metrics configured (shown first).
#'   If NULL and `dfMeasureMetrics` is derived from installed YAMLs, defaults to those measures.
#' @param nWindowLength `numeric` Rolling window length *W* used to detect consecutive
#'   repeats. Should match the `WindowLength` configured on the metric YAMLs. Default: `3`.
#' @param strGroupCol `character` Column in `dfMappedSUBJ` for grouping. Default: `"invid"`.
#' @param strGroupLevel `character` Group level label. Default: `"Site"`.
#' @param dfReportingResults `data.frame` Optional. Standard reportingResults data with columns:
#'   `GroupID`, `GroupLevel`, `MetricID`, `Score`, `Flag`. Passed to widget to show metric badges.
#' @param dfReportingMetrics `data.frame` Optional. Standard reportingMetrics data with columns:
#'   `MetricID`, `Metric`. Passed through to widget for future use.
#'
#' @return A [Widget_RecordDuplication()] htmlwidget.
#'
#' @examples
#' \dontrun{
#' Report_RecordDuplication(
#'   dfMappedVS = lData$Mapped_VS,
#'   dfMappedSUBJ = lData$Mapped_SUBJ,
#'   vPrioritizedMeasures = c("weight")
#' )
#' }
#'
#' @export
Report_RecordDuplication <- function(
  dfMappedVS = NULL,
  dfMappedLB = NULL,
  dfMappedSUBJ,
  vMeasuresVS = NULL,
  vMeasuresLB = NULL,
  vPrioritizedMeasures = NULL,
  nWindowLength = 3,
  strGroupCol = "invid",
  strGroupLevel = "Site",
  dfReportingResults = NULL,
  dfReportingMetrics = NULL
) {
  stopifnot(is.data.frame(dfMappedSUBJ))
  stopifnot("subjid" %in% names(dfMappedSUBJ))
  stopifnot(strGroupCol %in% names(dfMappedSUBJ))

  # Build subject-to-group lookup
  dfSubjGroup <- dfMappedSUBJ[, c("subjid", strGroupCol), drop = FALSE]
  names(dfSubjGroup) <- c("subjid", "GroupID")

  dfFlagged <- data.frame(
    subjid = character(0),
    GroupID = character(0),
    date = as.Date(character(0)),
    measure = character(0),
    value = numeric(0),
    RunID = integer(0),
    RunLength = integer(0),
    IsRepeatRun = integer(0),
    IsEvaluableWindow = integer(0),
    IsRepeatWindow = integer(0),
    stringsAsFactors = FALSE
  )

  # Process wide-format vitals
 if (!is.null(dfMappedVS) && nrow(dfMappedVS) > 0) {
    if (is.null(vMeasuresVS)) {
      # Default: all numeric columns except known identifiers
      id_cols <- c("subjid", "studyid", "invid", "vs_dt", "visnam", "vsperf_std")
      num_cols <- names(dfMappedVS)[sapply(dfMappedVS, is.numeric)]
      vMeasuresVS <- setdiff(num_cols, id_cols)
    }

    for (measure in vMeasuresVS) {
      if (!(measure %in% names(dfMappedVS))) next
      flagged <- Detect_ConsecutiveRepeats(
        df = dfMappedVS,
        strSubjectCol = "subjid",
        strDateCol = "vs_dt",
        strValueCol = measure,
        nWindowLength = nWindowLength
      )
      if (nrow(flagged) > 0) {
        flagged_out <- data.frame(
          subjid = flagged$subjid,
          date = flagged$vs_dt,
          measure = measure,
          value = flagged[[measure]],
          RunID = flagged$RunID,
          RunLength = flagged$RunLength,
          IsRepeatRun = flagged$IsRepeatRun,
          IsEvaluableWindow = flagged$IsEvaluableWindow,
          IsRepeatWindow = flagged$IsRepeatWindow,
          stringsAsFactors = FALSE
        )
        flagged_out <- merge(flagged_out, dfSubjGroup, by = "subjid", all.x = TRUE)
        dfFlagged <- rbind(dfFlagged, flagged_out[, names(dfFlagged)])
      }
    }
  }

  # Process long-format labs
  if (!is.null(dfMappedLB) && nrow(dfMappedLB) > 0) {
    if (is.null(vMeasuresLB)) {
      if ("lbtstnam" %in% names(dfMappedLB)) {
        vMeasuresLB <- unique(dfMappedLB$lbtstnam)
      }
    }

    if (!is.null(vMeasuresLB)) {
      for (measure in vMeasuresLB) {
        flagged <- Detect_ConsecutiveRepeats(
          df = dfMappedLB,
          strSubjectCol = "subjid",
          strDateCol = "lb_dt",
          strValueCol = "rptresn",
          strMeasureCol = "lbtstnam",
          strMeasureVal = measure,
          nWindowLength = nWindowLength
        )
        if (nrow(flagged) > 0) {
          flagged_out <- data.frame(
            subjid = flagged$subjid,
            date = flagged$lb_dt,
            measure = measure,
            value = flagged$rptresn,
            RunID = flagged$RunID,
            RunLength = flagged$RunLength,
            IsRepeatRun = flagged$IsRepeatRun,
            IsEvaluableWindow = flagged$IsEvaluableWindow,
            IsRepeatWindow = flagged$IsRepeatWindow,
            stringsAsFactors = FALSE
          )
          flagged_out <- merge(flagged_out, dfSubjGroup, by = "subjid", all.x = TRUE)
          dfFlagged <- rbind(dfFlagged, flagged_out[, names(dfFlagged)])
        }
      }
    }
  }

  # Auto-derive measure -> MetricID mapping from installed metric YAMLs
  wf_path <- system.file("workflow/2_metrics", package = "gsm.kri")
  yaml_files <- list.files(wf_path, pattern = "^kri.*\\.yaml$", full.names = TRUE)
  dfMeasureMetrics <- do.call(rbind, lapply(yaml_files, function(f) {
    m <- yaml::read_yaml(f)$meta
    if (!is.null(m$ValueCol)) {
      data.frame(
        measure = m$ValueCol,
        MetricID = paste0("Analysis_", m$ID),
        stringsAsFactors = FALSE
      )
    }
  }))
  if (is.null(dfMeasureMetrics) || nrow(dfMeasureMetrics) == 0) dfMeasureMetrics <- NULL

  # Auto-set vPrioritizedMeasures if not provided and measure mapping was derived
  if (is.null(vPrioritizedMeasures) && !is.null(dfMeasureMetrics)) {
    vPrioritizedMeasures <- dfMeasureMetrics$measure
  }

  Widget_RecordDuplication(
    dfFlagged = dfFlagged,
    dfReportingResults = dfReportingResults,
    dfReportingMetrics = dfReportingMetrics,
    dfMeasureMetrics = dfMeasureMetrics,
    strGroupLevel = strGroupLevel,
    vPrioritizedMeasures = vPrioritizedMeasures,
    nWindowLength = nWindowLength
  )
}
