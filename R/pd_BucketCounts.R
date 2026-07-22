#' Premature-death category counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts the [pd_Classify()] category of each enrolled subject per
#' `strGroupCol`. `.drop = FALSE` keeps every category present for every group so
#' the stacked bar and its colors stay aligned.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#' @param strGroupCol `character` Column to group by. Default "studyid".
#' @param strOuterCol `character` Optional parent column for a two-tier
#'   (multicategory) axis. `NULL` (default) is the flat one-tier count.
#'
#' @return A `data.frame` with `GroupID`, `Bucket`, `n` (and `Outer` when
#'   `strOuterCol` is set).
#' @export
pd_BucketCounts <- function(
  dfClassified,
  strGroupCol = "studyid",
  strOuterCol = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfClassified),
    message = "dfClassified is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !(is.character(strGroupCol) && length(strGroupCol) == 1),
    message = "strGroupCol must be a length-1 character"
  )
  gsm.core::stop_if(
    cnd = !strGroupCol %in% names(dfClassified),
    message = "strGroupCol is not a column in dfClassified"
  )
  gsm.core::stop_if(
    cnd = !"Category" %in% names(dfClassified),
    message = "dfClassified must contain 'Category'"
  )
  gsm.core::stop_if(
    cnd = !is.null(strOuterCol) &&
      !(is.character(strOuterCol) && length(strOuterCol) == 1),
    message = "strOuterCol must be NULL or a length-1 character"
  )
  gsm.core::stop_if(
    cnd = !is.null(strOuterCol) && !strOuterCol %in% names(dfClassified),
    message = "strOuterCol is not a column in dfClassified"
  )

  df <- tibble::tibble(
    GroupID = dfClassified[[strGroupCol]],
    Bucket = dfClassified$Category
  )

  if (is.null(strOuterCol)) {
    return(
      dplyr::count(df, .data$GroupID, .data$Bucket, name = "n", .drop = FALSE)
    )
  }

  outer <- dfClassified[[strOuterCol]]
  df$Outer <- dplyr::if_else(is.na(outer), "Unknown", as.character(outer))

  df %>%
    dplyr::count(
      .data$Outer,
      .data$GroupID,
      .data$Bucket,
      name = "n",
      .drop = FALSE
    ) %>%
    dplyr::arrange(.data$Outer, .data$GroupID)
}
