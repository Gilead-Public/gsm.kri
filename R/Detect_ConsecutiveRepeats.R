#' Detect Consecutive Repeated Measures
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Annotates measurement records with consecutive-repeat information using a rolling window
#' of length `nWindowLength`. For each subject, records are ordered chronologically and a
#' window of length *W* is slid across the ordered values; a window is a *repeat window* when
#' all *W* values in it are identical.
#'
#' This is the shared workhorse behind [Count_Duplicates()] (metric workflows, which sum the
#' window indicators) and [Report_RecordDuplication()] (drill-down report, which highlights
#' the underlying runs). It supports both wide-format data (e.g. vitals with a single value
#' column) and long-format data (e.g. labs where a measure column identifies the test).
#'
#' @param df `data.frame` Input data with one row per measurement record.
#' @param strSubjectCol `character` Column name for subject identifier. Default: `"subjid"`.
#' @param strDateCol `character` Column name for date/ordering. Default: `"vs_dt"`.
#' @param strValueCol `character` Column name for the measurement value. Required.
#' @param strMeasureCol `character` Optional column name identifying the measure/test
#'   (for long-format data like labs). When provided, data is filtered to `strMeasureVal`.
#' @param strMeasureVal `character` Value to filter on in `strMeasureCol`. Required if
#'   `strMeasureCol` is provided.
#' @param nWindowLength `numeric` Rolling window length *W*. Must be a whole number >= 2.
#'   Default: `3`.
#'
#' @return A `data.frame` containing the input rows (filtered to the specified measure if
#'   applicable, with `NA` values in `strValueCol` dropped), ordered by subject and date,
#'   with five added integer columns:
#'   - `RunID`: index of the maximal run of consecutive identical values the record belongs
#'     to, numbered within subject.
#'   - `RunLength`: length of that run.
#'   - `IsRepeatRun`: 1 when `RunLength >= nWindowLength`, i.e. the record is part of a run
#'     long enough to produce at least one repeat window. Intended for report highlighting.
#'   - `IsEvaluableWindow`: 1 when a full window of length *W* ends at this record. The first
#'     `W - 1` records for each subject are 0.
#'   - `IsRepeatWindow`: 1 when the window ending at this record contains *W* identical
#'     values. Always 0 where `IsEvaluableWindow` is 0.
#'
#' @details
#' Windows are attributed to the record at which they *end*, which makes the metric counts
#' expressible as column sums:
#'
#' - numerator = `sum(IsRepeatWindow)`
#' - denominator = `sum(IsEvaluableWindow)` = `total_measurements - (W - 1)` per subject
#'
#' Subjects with fewer than *W* non-missing measurements contribute 0 to both, so they are
#' excluded from scoring rather than scored as a rate of 0.
#'
#' Missing values are dropped *before* windowing, so two identical values separated by a
#' missing visit are treated as adjacent. Ties in `strDateCol` are resolved by input order
#' via a stable sort.
#'
#' A maximal run of `L` identical consecutive values contributes `max(0, L - W + 1)` repeat
#' windows, which is the relationship the report relies on to reconcile its highlighting with
#' the metric.
#'
#' @examples
#' # Wide format (vitals) -- W = 3
#' df_vs <- data.frame(
#'   subjid = rep("S1", 6),
#'   vs_dt = as.Date("2024-01-01") + seq(0, 150, by = 30),
#'   weight = c(10, 10, 10, 1, 5, 6)
#' )
#' Detect_ConsecutiveRepeats(df_vs, strValueCol = "weight", nWindowLength = 3)
#'
#' # Long format (labs)
#' df_lb <- data.frame(
#'   subjid = rep("S1", 4),
#'   lb_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
#'   lbtstnam = "ALT",
#'   rptresn = c(25, 25, 25, 35)
#' )
#' Detect_ConsecutiveRepeats(
#'   df_lb,
#'   strDateCol = "lb_dt", strValueCol = "rptresn",
#'   strMeasureCol = "lbtstnam", strMeasureVal = "ALT"
#' )
#'
#' @export
Detect_ConsecutiveRepeats <- function(
  df,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  # Input validation
  stopifnot(is.data.frame(df))
  stopifnot(is.character(strSubjectCol) && length(strSubjectCol) == 1)
  stopifnot(is.character(strDateCol) && length(strDateCol) == 1)
  stopifnot(is.character(strValueCol) && length(strValueCol) == 1)
  stopifnot(strSubjectCol %in% names(df))
  stopifnot(strDateCol %in% names(df))
  stopifnot(strValueCol %in% names(df))

  nWindowLength <- ParseWindowLength(nWindowLength)

  if (!is.null(strMeasureCol)) {
    stopifnot(is.character(strMeasureCol) && length(strMeasureCol) == 1)
    stopifnot(!is.null(strMeasureVal))
    stopifnot(strMeasureCol %in% names(df))
    # Filter to specified measure
    df <- df[df[[strMeasureCol]] == strMeasureVal, , drop = FALSE]
  }

  # Remove rows with NA values -- missing visits are dropped, not treated as run breaks
  df <- df[!is.na(df[[strValueCol]]), , drop = FALSE]

  if (nrow(df) == 0) {
    df$RunID <- integer(0)
    df$RunLength <- integer(0)
    df$IsRepeatRun <- integer(0)
    df$IsEvaluableWindow <- integer(0)
    df$IsRepeatWindow <- integer(0)
    return(df)
  }

  # Order by subject then date (stable sort preserves input order for ties)
  df <- df[order(df[[strSubjectCol]], df[[strDateCol]]), , drop = FALSE]
  rownames(df) <- NULL

  subjects <- df[[strSubjectCol]]
  values <- df[[strValueCol]]

  nRunID <- integer(nrow(df))
  nRunLength <- integer(nrow(df))
  isEvaluable <- integer(nrow(df))
  isRepeat <- integer(nrow(df))

  for (subj in unique(subjects)) {
    idx <- which(subjects == subj)
    vSubjValues <- values[idx]
    nMeasures <- length(vSubjValues)

    # Maximal runs of consecutive identical values within the subject
    vRuns <- rle(as.character(vSubjValues))
    nRunID[idx] <- rep(seq_along(vRuns$lengths), vRuns$lengths)
    nRunLength[idx] <- rep(vRuns$lengths, vRuns$lengths)

    if (nMeasures < nWindowLength) next

    # A window of length W ends at each position >= W. It is a repeat window when the
    # record's run has covered the full window, i.e. the run is at least W long by here.
    vRunPosition <- sequence(vRuns$lengths) # position within the record's run
    vWindowEnds <- nWindowLength:nMeasures
    isEvaluable[idx[vWindowEnds]] <- 1L
    isRepeat[idx[vWindowEnds]] <- as.integer(vRunPosition[vWindowEnds] >= nWindowLength)
  }

  df$RunID <- nRunID
  df$RunLength <- nRunLength
  df$IsRepeatRun <- as.integer(nRunLength >= nWindowLength)
  df$IsEvaluableWindow <- isEvaluable
  df$IsRepeatWindow <- isRepeat

  return(df)
}

#' Coerce a window length from metric metadata
#'
#' Metric YAML `meta` values arrive as character when authored inline, so accept either and
#' validate that the result is a whole number of at least 2.
#'
#' @param nWindowLength `numeric` or `character` window length.
#'
#' @return `integer` validated window length.
#'
#' @keywords internal
#' @noRd
ParseWindowLength <- function(nWindowLength) {
  if (is.character(nWindowLength)) {
    nWindowLength <- suppressWarnings(as.numeric(nWindowLength))
  }

  stopifnot(
    "nWindowLength must be a single whole number >= 2" =
      is.numeric(nWindowLength) &&
        length(nWindowLength) == 1 &&
        !is.na(nWindowLength) &&
        nWindowLength >= 2 &&
        nWindowLength == round(nWindowLength)
  )

  as.integer(nWindowLength)
}
