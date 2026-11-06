#' Detect consecutive repeated measurements
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts, per subject, the rolling windows of `nWindowLength` consecutive
#' measurements in which every value is identical. Missing values are dropped
#' before windows are formed. Records are ordered by `strDateCol` within
#' subject, then by `strOrderCol` to break same-date ties. Records with a
#' missing subject are dropped with a warning.
#'
#' @param df `data.frame` One row per measurement record.
#' @param strValueCol `character` Column holding the measurement value.
#' @param strSubjectCol `character` Subject identifier column. Default
#'   `"subjid"`.
#' @param strDateCol `character` Date/ordering column. Default `"vs_dt"`.
#' @param strOrderCol `character` Optional column(s) used, in order, to break
#'   ties on `strDateCol` (e.g. an intra-visit measurement time or `"visit"`).
#'   Default `NULL`, in which case tied records keep their input order.
#' @param strMeasureCol `character` Optional column identifying the measure,
#'   for long-format data. When supplied, `df` is filtered to `strMeasureVal`.
#' @param strMeasureVal `character` Value of `strMeasureCol` to keep. Required
#'   when `strMeasureCol` is supplied.
#' @param nWindowLength `numeric` Window length; a whole number >= 2. Default
#'   `3`.
#'
#' @return A `data.frame` with one row per subject in `df` (after measure
#'   filtering): the subject column, `Numerator` (count of all-equal windows),
#'   and `Denominator` (`n - nWindowLength + 1`, floored at 0, where `n` is the
#'   subject's non-missing measurement count). Subjects with a `Denominator` of
#'   0 contribute nothing to a rate.
#'
#' @examples
#' df <- data.frame(
#'   subjid = rep(c("A", "B"), each = 5),
#'   vs_dt = rep(as.Date("2024-01-01") + 0:4, 2),
#'   weight = c(10, 10, 5, 3, 10, 10, 10, 10, 10, 10)
#' )
#' Detect_ConsecutiveRepeats(df, "weight")
#' @export
Detect_ConsecutiveRepeats <- function(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strOrderCol = NULL,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  dfMarked <- MarkConsecutiveRepeats(
    df,
    strValueCol,
    strSubjectCol = strSubjectCol,
    strDateCol = strDateCol,
    strOrderCol = strOrderCol,
    strMeasureCol = strMeasureCol,
    strMeasureVal = strMeasureVal,
    nWindowLength = nWindowLength
  )

  if (!is.null(strMeasureCol)) {
    df <- df[df[[strMeasureCol]] %in% strMeasureVal, , drop = FALSE]
  }
  # Subjects whose values are all missing still get a 0/0 row.
  vSubjects <- unique(df[[strSubjectCol]])
  bMissing <- is.na(vSubjects)
  if (any(bMissing)) {
    nDropped <- sum(is.na(df[[strSubjectCol]]))
    cli::cli_warn(
      "Dropped {nDropped} record{?s} with a missing {.field {strSubjectCol}}."
    )
    vSubjects <- vSubjects[!bMissing]
  }
  SummarizeConsecutiveRepeats(dfMarked, vSubjects, strSubjectCol, nWindowLength)
}

#' Mark measurements inside consecutive repeating windows
#'
#' The windowing engine behind [Detect_ConsecutiveRepeats()] and
#' [rm_Classify()]. Returns every non-missing measurement in evaluation order,
#' marked when it sits inside a rolling window of `nWindowLength` identical
#' consecutive values. Records with a missing value or subject are dropped.
#'
#' @inheritParams Detect_ConsecutiveRepeats
#'
#' @return `df` without rows whose value or subject is missing (filtered to
#'   `strMeasureVal` when `strMeasureCol` is supplied), ordered by subject, then
#'   `strDateCol`, then `strOrderCol`, with three columns added:
#'   * `seq`: position of the measurement within its subject.
#'   * `in_repeat_window`: `TRUE` when the measurement belongs to at least one
#'     all-identical window.
#'   * `window_start`: `TRUE` when the window starting at this measurement is
#'     all-identical. Its per-subject sum is the repeat-window count.
#' @noRd
MarkConsecutiveRepeats <- function(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strOrderCol = NULL,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data frame.")
  }
  if (
    !is.numeric(nWindowLength) ||
      length(nWindowLength) != 1 ||
      !is.finite(nWindowLength) ||
      nWindowLength < 2 ||
      nWindowLength != round(nWindowLength)
  ) {
    cli::cli_abort(
      "{.arg nWindowLength} must be a single whole number >= 2, not {.val {nWindowLength}}."
    )
  }
  if (!is.null(strMeasureCol) && is.null(strMeasureVal)) {
    cli::cli_abort(
      "{.arg strMeasureVal} is required when {.arg strMeasureCol} is supplied."
    )
  }
  # Validate each argument before c(), which would coerce numerics to strings
  # and silently drop NULLs.
  lScalarCols <- list(
    strValueCol = strValueCol,
    strSubjectCol = strSubjectCol,
    strDateCol = strDateCol
  )
  if (!is.null(strMeasureCol)) {
    lScalarCols$strMeasureCol <- strMeasureCol
  }
  for (strArg in names(lScalarCols)) {
    x <- lScalarCols[[strArg]]
    if (!is.character(x) || length(x) != 1 || is.na(x)) {
      cli::cli_abort(
        "{.arg {strArg}} must be a single non-missing character string."
      )
    }
  }
  if (
    !is.null(strOrderCol) &&
      (!is.character(strOrderCol) || !length(strOrderCol) || anyNA(strOrderCol))
  ) {
    cli::cli_abort(
      "{.arg strOrderCol} must be a character vector without missing values."
    )
  }
  lCols <- c(strValueCol, strSubjectCol, strDateCol, strOrderCol, strMeasureCol)
  strMissing <- setdiff(lCols, names(df))
  if (length(strMissing)) {
    cli::cli_abort("Column{?s} not found in {.arg df}: {.val {strMissing}}.")
  }
  # The marking columns are written onto df, so an input column with one of
  # these names would be overwritten before it is used.
  strReserved <- intersect(lCols, c("seq", "in_repeat_window", "window_start"))
  if (length(strReserved)) {
    cli::cli_abort("Column{?s} {.val {strReserved}} {?is/are} reserved for the output.")
  }

  if (!is.null(strMeasureCol)) {
    df <- df[df[[strMeasureCol]] %in% strMeasureVal, , drop = FALSE]
  }
  df <- df[!is.na(df[[strValueCol]]) & !is.na(df[[strSubjectCol]]), , drop = FALSE]
  # arrange() is stable and sorts in the C locale, so full ties keep input order.
  df <- dplyr::arrange(
    df,
    dplyr::pick(dplyr::all_of(c(strSubjectCol, strDateCol, strOrderCol)))
  )

  n <- nrow(df)
  if (n == 0) {
    df$seq <- integer(0)
    df$in_repeat_window <- logical(0)
    df$window_start <- logical(0)
    return(df)
  }
  vSubject <- df[[strSubjectCol]]
  vValue <- df[[strValueCol]]
  bNewSubject <- c(TRUE, vSubject[-1] != vSubject[-n])
  # A run breaks on a new subject or a changed value, as rle() does per subject.
  bNewRun <- bNewSubject | c(TRUE, vValue[-1] != vValue[-n])
  vRun <- cumsum(bNewRun)
  vRunLength <- tabulate(vRun)[vRun]
  vPosInRun <- seq_len(n) - match(vRun, vRun) + 1L
  vSubjectStart <- cummax(ifelse(bNewSubject, seq_len(n), 0L))

  df$seq <- seq_len(n) - vSubjectStart + 1L
  df$in_repeat_window <- vRunLength >= nWindowLength
  df$window_start <- df$in_repeat_window &
    vPosInRun <= vRunLength - nWindowLength + 1
  rownames(df) <- NULL
  df
}

#' Summarize marked measurements per subject
#'
#' The `Numerator` / `Denominator` step shared by
#' [Detect_ConsecutiveRepeats()] and [rm_Classify()].
#'
#' @param dfMarked `data.frame` Output of `MarkConsecutiveRepeats()`.
#' @param vSubjects Unique, non-missing subjects to report, in output order.
#'   A subject without marked rows gets 0/0.
#' @param strSubjectCol `character` Subject identifier column.
#' @param nWindowLength `numeric` Window length used for the marks.
#'
#' @return A `data.frame` with the subject column, `Numerator` and
#'   `Denominator`, one row per element of `vSubjects`.
#' @noRd
SummarizeConsecutiveRepeats <- function(dfMarked, vSubjects, strSubjectCol, nWindowLength) {
  f <- factor(dfMarked[[strSubjectCol]], levels = vSubjects)
  dfOut <- data.frame(
    SubjectID = vSubjects,
    Numerator = unname(vapply(split(dfMarked$window_start, f), sum, numeric(1))),
    Denominator = as.numeric(pmax(0, tabulate(f, nbins = length(vSubjects)) - nWindowLength + 1))
  )
  names(dfOut)[1] <- strSubjectCol
  dfOut
}
