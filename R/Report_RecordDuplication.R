#' Generate Record Duplication Report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Convenience function that runs [Flag_Duplicates()] across multiple measures and
#' produces a [Widget_RecordDuplication()] htmlwidget. Supports both wide-format
#' vitals data and long-format lab data.
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
#' @param strGroupCol `character` Column in `dfMappedSUBJ` for grouping. Default: `"invid"`.
#' @param strGroupLevel `character` Group level label. Default: `"Site"`.
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
  strGroupCol = "invid",
  strGroupLevel = "Site"
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
    is_duplicate = integer(0),
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
      flagged <- Flag_Duplicates(
        df = dfMappedVS,
        strSubjectCol = "subjid",
        strDateCol = "vs_dt",
        strValueCol = measure
      )
      if (nrow(flagged) > 0) {
        flagged_out <- data.frame(
          subjid = flagged$subjid,
          date = flagged$vs_dt,
          measure = measure,
          value = flagged[[measure]],
          is_duplicate = flagged$is_duplicate,
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
        flagged <- Flag_Duplicates(
          df = dfMappedLB,
          strSubjectCol = "subjid",
          strDateCol = "lb_dt",
          strValueCol = "rptresn",
          strMeasureCol = "lbtstnam",
          strMeasureVal = measure
        )
        if (nrow(flagged) > 0) {
          flagged_out <- data.frame(
            subjid = flagged$subjid,
            date = flagged$lb_dt,
            measure = measure,
            value = flagged$rptresn,
            is_duplicate = flagged$is_duplicate,
            stringsAsFactors = FALSE
          )
          flagged_out <- merge(flagged_out, dfSubjGroup, by = "subjid", all.x = TRUE)
          dfFlagged <- rbind(dfFlagged, flagged_out[, names(dfFlagged)])
        }
      }
    }
  }

  Widget_RecordDuplication(
    dfFlagged = dfFlagged,
    strGroupLevel = strGroupLevel,
    vPrioritizedMeasures = vPrioritizedMeasures
  )
}
