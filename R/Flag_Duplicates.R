#' Flag Duplicate Records
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Flags records as duplicates when their value matches any previous value for the same subject.
#' The first record for each subject is never flagged as a duplicate. Supports both wide-format
#' data (e.g., vitals with a single value column) and long-format data (e.g., labs where a
#' measure column identifies the test).
#'
#' @param df `data.frame` Input data with one row per measurement record.
#' @param strSubjectCol `character` Column name for subject identifier. Default: `"subjid"`.
#' @param strDateCol `character` Column name for date/ordering. Default: `"vs_dt"`.
#' @param strValueCol `character` Column name for the measurement value. Required.
#' @param strMeasureCol `character` Optional column name identifying the measure/test
#'   (for long-format data like labs). When provided, data is filtered to `strMeasureVal`.
#' @param strMeasureVal `character` Value to filter on in `strMeasureCol`. Required if
#'   `strMeasureCol` is provided.
#'
#' @return A `data.frame` containing the input rows (filtered to the specified measure if
#'   applicable), with two added integer columns:
#'   - `is_duplicate` (1 = duplicate, 0 = not): a record is duplicate if its value matches
#'     any prior value for the same subject.
#'   - `is_source` (1 = source of a duplicate, 0 = not): a record is the source if it was
#'     the earliest prior record whose value was later copied by a duplicate record.
#'   Rows with NA values in `strValueCol` are excluded.
#'
#' @details
#' The function:
#' 1. Optionally filters to a specific measure (long-format support)
#' 2. Removes rows where the value column is NA
#' 3. Orders records by subject and date
#' 4. For each subject, marks a record as duplicate (1) if its value exactly matches
#'    any previously recorded value for that subject. The first record is always 0.
#'
#' @examples
#' # Wide format (vitals)
#' df_vs <- data.frame(
#'   subjid = c("S1", "S1", "S1", "S2", "S2"),
#'   vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-01-01", "2024-02-01")),
#'   weight = c(75.0, 75.0, 76.0, 80.0, 80.0)
#' )
#' Flag_Duplicates(df_vs, strValueCol = "weight")
#'
#' # Long format (labs)
#' df_lb <- data.frame(
#'   subjid = c("S1", "S1", "S1", "S1"),
#'   lb_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01", "2024-02-01")),
#'   lbtstnam = c("ALT", "ALT", "AST", "AST"),
#'   rptresn = c(25, 25, 30, 35)
#' )
#' Flag_Duplicates(df_lb, strDateCol = "lb_dt", strValueCol = "rptresn",
#'                 strMeasureCol = "lbtstnam", strMeasureVal = "ALT")
#'
#' @export
Flag_Duplicates <- function(
  df,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL
) {
  # Input validation
  stopifnot(is.data.frame(df))
  stopifnot(is.character(strSubjectCol) && length(strSubjectCol) == 1)
  stopifnot(is.character(strDateCol) && length(strDateCol) == 1)
  stopifnot(is.character(strValueCol) && length(strValueCol) == 1)
  stopifnot(strSubjectCol %in% names(df))
  stopifnot(strDateCol %in% names(df))
  stopifnot(strValueCol %in% names(df))

  if (!is.null(strMeasureCol)) {
    stopifnot(is.character(strMeasureCol) && length(strMeasureCol) == 1)
    stopifnot(!is.null(strMeasureVal))
    stopifnot(strMeasureCol %in% names(df))
    # Filter to specified measure
    df <- df[df[[strMeasureCol]] == strMeasureVal, , drop = FALSE]
  }

  # Remove rows with NA values
  df <- df[!is.na(df[[strValueCol]]), , drop = FALSE]

  if (nrow(df) == 0) {
    df$is_duplicate <- integer(0)
    df$is_source <- integer(0)
    return(df)
  }

  # Order by subject then date (stable sort preserves row position for ties)
  df <- df[order(df[[strSubjectCol]], df[[strDateCol]]), , drop = FALSE]
  rownames(df) <- NULL

  # Flag duplicates: a record is duplicate if its value matches any prior value for same subject
  subjects <- df[[strSubjectCol]]
  values <- df[[strValueCol]]
  is_dup <- integer(nrow(df))

  unique_subjects <- unique(subjects)
  for (subj in unique_subjects) {
    idx <- which(subjects == subj)
    if (length(idx) <= 1) next
    seen_values <- values[idx[1]]
    for (i in idx[-1]) {
      if (values[i] %in% seen_values) {
        is_dup[i] <- 1L
      }
      seen_values <- c(seen_values, values[i])
    }
  }

  # Compute is_source: earliest prior record per subject whose value was later duplicated
  is_src <- integer(nrow(df))
  for (subj in unique_subjects) {
    idx <- which(subjects == subj)
    if (length(idx) <= 1) next
    for (i in idx) {
      if (is_dup[i] == 1L) {
        prior_idx <- idx[idx < i]
        matching <- prior_idx[values[prior_idx] == values[i]]
        if (length(matching) > 0) {
          is_src[matching[1]] <- 1L
        }
      }
    }
  }

  df$is_duplicate <- is_dup
  df$is_source <- is_src
  return(df)
}
