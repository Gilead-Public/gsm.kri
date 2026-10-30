#' Mark measurements inside consecutive repeat windows
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns every non-missing measurement in the order
#' [Detect_ConsecutiveRepeats()] evaluates it, marked when it sits inside a
#' rolling window of `nWindowLength` identical consecutive values. It applies
#' the same validation, ordering and window rule, so summing `window_start` per
#' subject reproduces the `Numerator` of [Detect_ConsecutiveRepeats()].
#' Records with a missing subject are dropped.
#'
#' @inheritParams Detect_ConsecutiveRepeats
#'
#' @return `df` without rows whose value is missing, ordered by subject, then
#'   `strDateCol`, then `strOrderCol`, with three columns added:
#'   * `seq`: position of the measurement within its subject.
#'   * `in_repeat_window`: `TRUE` when the measurement belongs to at least one
#'     all-identical window.
#'   * `window_start`: `TRUE` when the window starting at this measurement is
#'     all-identical. Its per-subject sum is the repeat-window count.
#'
#' @examples
#' df <- data.frame(
#'   subjid = rep(c("A", "B"), each = 5),
#'   vs_dt = rep(as.Date("2024-01-01") + 0:4, 2),
#'   weight = c(10, 10, 5, 3, 10, 10, 10, 10, 10, 10)
#' )
#' Mark_ConsecutiveRepeats(df, "weight")
#' @export
Mark_ConsecutiveRepeats <- function(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strOrderCol = NULL,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  # Validation mirrors Detect_ConsecutiveRepeats(), which is left unchanged so
  # the KRI code is untouched; a test checks the two agree.
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
