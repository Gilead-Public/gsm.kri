#' Long-format premature-death bucket rows for gsm.viz `bars`
#'
#' @description
#' Adapts [pd_BucketCounts()] to one row per (group, category) with within-group
#' `pct`, plus stable `OuterGroupID` / `Level` keys for the country->site
#' click-filter drilldown. `.drop = FALSE` zero-count cells are preserved.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#' @param nWindowDays `numeric` Window in days.
#' @param strGroupCol `character` Column rendered on the category axis.
#' @param strOuterCol `character` Optional parent column carried as `OuterGroupID`
#'   (the site chart passes `"country"` so its rows drive the country->site
#'   click-filter narrowing and the click payload). Default `NULL`.
#'
#' @return `data.frame` with `GroupID`, `OuterGroupID`, `Category`, `n`, `pct`, `Level`.
#' @export
pd_BucketRows <- function(
  dfClassified,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strOuterCol = NULL
) {
  counts <- pd_BucketCounts(dfClassified, strGroupCol, strOuterCol)
  level <- switch(
    strGroupCol,
    studyid = "study",
    country = "country",
    invid = "site",
    strGroupCol
  )
  counts %>%
    dplyr::group_by(.data$GroupID) %>%
    # Materialize the group total as a column so the if_else condition is
    # vectorized (dplyr::if_else rejects a scalar `sum()` condition against a
    # vector branch).
    dplyr::mutate(GroupTotal = sum(.data$n)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      pct = dplyr::if_else(
        .data$GroupTotal > 0,
        100 * .data$n / .data$GroupTotal,
        0
      )
    ) %>%
    dplyr::transmute(
      GroupID = as.character(.data$GroupID),
      OuterGroupID = if (is.null(strOuterCol)) {
        NA_character_
      } else {
        as.character(.data$Outer)
      },
      Category = as.character(.data$Bucket),
      n = as.integer(.data$n),
      pct = .data$pct,
      Level = level
    )
}

#' Serializable gsm.viz `bars` spec for the premature-death bucket chart
#'
#' @description
#' The data-driven half of the spec (mapping, orientation, position, stat,
#' scales, legend). Non-serializable pieces (tooltip formatter, click/hover
#' callbacks) are attached in `Widget_PrematureDeathBucketBar.js`.
#'
#' @param nWindowDays `numeric` Window in days (color/order vocabulary).
#' @param strGroupLabel `character` Category-axis label.
#' @param zoom `list` or `NULL` Optional `gsm.viz` zoom spec (e.g.
#'   `list(enabled = TRUE, mode = "x")`). Attached only when non-`NULL`; the
#'   site chart opts in so its many bars can be zoomed, the study/country charts
#'   do not. Default `NULL` (no zoom).
#'
#' @return A named `list` — a `gsm.viz` `bars` spec without callbacks.
#' @export
pd_BucketBarSpec <- function(
  nWindowDays = 90,
  strGroupLabel = "Group",
  zoom = NULL
) {
  spec <- list(
    mapping = list(x = "GroupID", y = "n", fill = "Category"),
    orientation = "vertical",
    position = "stack",
    stat = "identity",
    scales = list(
      x = list(label = strGroupLabel),
      y = list(label = "Subjects"),
      fill = list(
        colors = as.list(pd_CategoryColors(nWindowDays)),
        order = as.list(pd_DisplayOrder(nWindowDays)),
        label = "Category"
      )
    )
  )
  if (!is.null(zoom)) {
    spec$zoom <- zoom
  }
  spec
}
