#' Flag Duplicate Measurement Records
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Record-level helper that marks measurement records as duplicates when
#' their value matches any previously recorded value for the same subject.
#' Supports both wide-format data (e.g. vitals, where each measure is its
#' own column) and long-format data (e.g. labs, where the measure name is a
#' row value).
#'
#' @param df `data.frame` Input data containing at least the subject, date,
#'   and value columns.
#' @param strValueCol `character` Column containing the measurement value to
#'   check for duplicates (e.g. `"weight"`, `"rptresn"`).
#' @param strSubjectCol `character` Column identifying the subject (e.g.
#'   `"subjid"`).
#' @param strDateCol `character` Column used to order records chronologically
#'   (e.g. `"vs_dt"`).
#' @param strMeasureCol `character` Optional column containing the measure
#'   name, used to filter to a specific test in long-format data (e.g.
#'   `"lbtstnam"`).
#' @param strMeasureVal `character` Optional value in `strMeasureCol` to
#'   retain (e.g. `"ALT (SGPT)"`). Required when `strMeasureCol` is provided.
#'
#' @return A filtered `data.frame` with an added `is_duplicate` logical
#'   column. Rows with `NA` in `strValueCol` are dropped, as are rows that do
#'   not match `strMeasureVal` when `strMeasureCol` is specified.
#'
#' @examples
#' # Wide-format (vitals): each measure is its own column.
#' dfVitals <- data.frame(
#'   subjid = c("001", "001", "001"),
#'   vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
#'   weight = c(72.3, 72.3, 73.1)
#' )
#' Flag_Duplicates(df = dfVitals, strValueCol = "weight")
#'
#' # Long-format (labs): measure name is a row value.
#' dfLabs <- data.frame(
#'   subjid = c("001", "001", "001", "001"),
#'   lb_dt = as.Date(c("2024-01-01", "2024-01-01", "2024-02-01", "2024-02-01")),
#'   lbtstnam = c("ALT (SGPT)", "AST (SGOT)", "ALT (SGPT)", "AST (SGOT)"),
#'   rptresn = c(20, 20, 20, 30)
#' )
#' Flag_Duplicates(
#'   df = dfLabs,
#'   strValueCol = "rptresn",
#'   strDateCol = "lb_dt",
#'   strMeasureCol = "lbtstnam",
#'   strMeasureVal = "ALT (SGPT)"
#' )
#'
#' @export
Flag_Duplicates <- function(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strMeasureCol = NULL,
  strMeasureVal = NULL
) {
  if (!is.null(strMeasureCol)) {
    df <- df[df[[strMeasureCol]] == strMeasureVal, , drop = FALSE]
  }

  df <- df[!is.na(df[[strValueCol]]), , drop = FALSE]

  order_idx <- order(df[[strSubjectCol]], df[[strDateCol]], seq_len(nrow(df)))
  df <- df[order_idx, , drop = FALSE]

  df$is_duplicate <- FALSE
  seen <- new.env(parent = emptyenv())

  for (i in seq_len(nrow(df))) {
    subj <- as.character(df[[strSubjectCol]][i])
    val <- df[[strValueCol]][i]

    prior_vals <- seen[[subj]]
    if (!is.null(prior_vals) && val %in% prior_vals) {
      df$is_duplicate[i] <- TRUE
    }

    seen[[subj]] <- c(prior_vals, val)
  }

  rownames(df) <- NULL
  df
}
