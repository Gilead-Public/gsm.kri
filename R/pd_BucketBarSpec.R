#' Long-format premature-death bucket rows for gsm.viz `bars`
#'
#' @description
#' Adapts [pd_BucketCounts()] to one row per (group, category) with within-group
#' `pct`, plus stable `OuterGroupID` / `Level` keys for the country->site
#' click-filter drilldown. Only categories a group actually has get a row.
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
#' Mapping, orientation, position, stat, scales, legend, value labels, and the
#' tooltip formatter -- ready to hand to [gsm.vizr::bars()]. Click/hover
#' selection is left to the widget's own `gsm-viz-select` event, not a spec
#' callback.
#'
#' Each segment carries its value on the bar: counts in the stack and dodge
#' views, percentages in the native fill (100%) view.
#'
#' @param nWindowDays `numeric` Window in days (color/order vocabulary).
#' @param strGroupLabel `character` Category-axis label.
#' @param zoom `list` or `NULL` Optional `gsm.viz` zoom spec (e.g.
#'   `list(enabled = TRUE, mode = "x")`). Attached only when non-`NULL`; the
#'   site chart opts in so its many bars can be zoomed, the study/country charts
#'   do not. Enabling it also captions the chart with the scroll-to-zoom
#'   affordance. Default `NULL` (no zoom).
#' @param theme `list` or `NULL` Optional `gsm.viz` theme spec, passed through
#'   untouched (e.g. `list(dynamicCategoryAxis = TRUE)`, which drops categories
#'   off the axis once a disabled legend entry leaves them empty — the site
#'   chart opts in so hiding a death window thins its many bars). Omitted when
#'   `NULL`, leaving gsm.viz's own theme defaults in place. Default `NULL`.
#'
#' @return A named `list` — a `gsm.viz` `bars` spec without callbacks.
#' @export
pd_BucketBarSpec <- function(
  nWindowDays = 90,
  strGroupLabel = "Group",
  zoom = NULL,
  theme = NULL
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
    ),
    # gsm.viz "auto" follows the native position control: raw counts while stat
    # is identity, percentages once the fill (100%) button sets stat = "percent".
    # Segments below gsm.viz's 16px floor stay blank.
    annotations = list(
      labels = list(segment = list(display = TRUE, value = "auto"))
    )
  )
  if (!is.null(theme)) {
    spec$theme <- theme
  }
  if (!is.null(zoom)) {
    spec$zoom <- zoom
    # Zoom is opt-in on the dense charts, where bars can be too thin to carry
    # their value label -- zooming widens them and the labels return. gsm.viz
    # builds no zoom config unless `enabled`, so only advertise it when it is on.
    if (isTRUE(zoom$enabled)) {
      spec$labels <- list(captions = "Scroll to zoom in; drag to pan.")
    }
  }
  # gsm.vizr serializes with na = "null", so a missing OuterGroupID (study/
  # country rows) arrives as JS null -- the `if (d.OuterGroupID)` falsy check
  # covers it without a "NA" string-compare.
  spec$tooltip <- list(
    formatter = gsm.vizr::js_hook(
      "
    function (count, context, details) {
      var d = (details && details.datum) || {};
      var lines = [d.Category + ' \u2014 Subjects: ' + d.n + ' (' + Number(d.pct).toFixed(1) + '%)'];
      // Only the site chart has a parent tier; study/country rows serialize a null OuterGroupID.
      if (d.OuterGroupID) lines.push('Country: ' + d.OuterGroupID);
      return lines;
    }"
    )
  )
  spec
}
