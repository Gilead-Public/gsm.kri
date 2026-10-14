#' Detect consecutive repeated measurements
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts, per subject, the rolling windows of `nWindowLength` consecutive
#' measurements in which every value is identical. Missing values are dropped 
#' before windows are formed. Records are ordered by `strDateCol` within 
#' subject, then by `strOrderCol` to break same-date ties.
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
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data frame.")
  }
  if (
    !is.numeric(nWindowLength) ||
      length(nWindowLength) != 1 ||
      is.na(nWindowLength) ||
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
  lCols <- c(strValueCol, strSubjectCol, strDateCol, strOrderCol, strMeasureCol)
  if (!is.character(lCols)) {
    cli::cli_abort("Column arguments must be character strings.")
  }
  strMissing <- setdiff(lCols, names(df))
  if (length(strMissing)) {
    cli::cli_abort("Column{?s} not found in {.arg df}: {.val {strMissing}}.")
  }

  if (!is.null(strMeasureCol)) {
    df <- df[df[[strMeasureCol]] %in% strMeasureVal, , drop = FALSE]
  }

  # Subjects whose values are all missing still get a 0/0 row.
  vSubjects <- unique(df[[strSubjectCol]])
  df <- df[!is.na(df[[strValueCol]]), , drop = FALSE]
  # arrange() is stable and sorts in the C locale, so full ties keep input order.
  df <- dplyr::arrange(
    df,
    dplyr::pick(dplyr::all_of(c(strSubjectCol, strDateCol, strOrderCol)))
  )

  lBySubject <- split(
    df[[strValueCol]],
    factor(df[[strSubjectCol]], levels = vSubjects)
  )
  nNumerator <- vapply(
    lBySubject,
    function(x) {
      nRuns <- rle(x)$lengths
      sum(pmax(0, nRuns - nWindowLength + 1))
    },
    numeric(1)
  )
  nDenominator <- pmax(0, lengths(lBySubject) - nWindowLength + 1)

  dfOut <- data.frame(
    SubjectID = vSubjects,
    Numerator = unname(nNumerator),
    Denominator = unname(as.numeric(nDenominator))
  )
  names(dfOut)[1] <- strSubjectCol
  dfOut
}
