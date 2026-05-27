#' Summarize Portfolio Overview
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Aggregates KRI results across studies into a portfolio-level rollup. Returns
#' a long-format summary with one row per (Group, MetricID) cell, where Group is
#' either the portfolio total or a value of a study-level grouping parameter
#' (e.g. therapeutic area, phase, status, product, protocol indication). Each
#' cell contains numerator, denominator, and rate values rolled up from the
#' latest snapshot.
#'
#' Per the design spec for #212, this helper:
#' - includes all metrics in `dfResults` (no filtering).
#' - sorts metrics by `MetricID` ascending.
#' - includes all studies in `dfResults`.
#' - uses the latest `SnapshotDate` only when multiple snapshots are present.
#'
#' @param dfResults `data.frame` Cross-study KRI results. Must include
#'   `StudyID`, `MetricID`, `GroupLevel`, `Numerator`, `Denominator`. May
#'   include `SnapshotDate`; if so, only the latest snapshot is retained.
#' @param dfGroups `data.frame` Study-level group metadata in long format with
#'   columns `StudyID`, `GroupLevel`, `Param`, `Value`. Used to look up
#'   per-study attributes for the drill-down rows.
#' @param strGroupLevel `character` The `GroupLevel` value in `dfResults` to
#'   summarize across. Default `"Site"`.
#' @param vGroupParams `character` Vector of study-level `Param` values from
#'   `dfGroups` to use as drill-down categories. Defaults to the five
#'   `reporting.groups` study-level params used in #212:
#'   `therapeutic_area`, `protocol_indication`, `phase`, `status`, `product`.
#'
#' @return `data.frame` long-format summary with columns:
#' - `GroupCategory`: name of the grouping (e.g. `"Total"`, `"therapeutic_area"`).
#' - `GroupValue`: the specific bucket value (e.g. `"Total"`, `"Oncology"`).
#' - `MetricID`: metric identifier.
#' - `Numerator`: summed numerator across studies in the bucket.
#' - `Denominator`: summed denominator across studies in the bucket.
#' - `Rate`: `Numerator / Denominator` (NA when denominator is 0).
#' - `NumStudies`: number of distinct studies contributing to the bucket.
#'
#' @examples
#' \dontrun{
#' # See pkgdown/menus/examples/Example_PortfolioOverview.Rmd
#' }
#' @export
SummarizePortfolioOverview <- function(
  dfResults,
  dfGroups = NULL,
  strGroupLevel = "Site",
  vGroupParams = c(
    "therapeutic_area",
    "protocol_indication",
    "phase",
    "status",
    "product"
  )
) {
  stopifnot(is.data.frame(dfResults))
  stopifnot(is.null(dfGroups) || is.data.frame(dfGroups))
  stopifnot(is.character(strGroupLevel) && length(strGroupLevel) == 1)
  stopifnot(is.character(vGroupParams))

  required_results_cols <- c(
    "StudyID",
    "MetricID",
    "GroupLevel",
    "Numerator",
    "Denominator"
  )
  missing_cols <- setdiff(required_results_cols, colnames(dfResults))
  if (length(missing_cols) > 0) {
    stop(paste(
      "dfResults is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Latest snapshot only (Q5), per-study: studies snapshot on independent
  # cadences, so a global max would silently drop any study whose most
  # recent snapshot pre-dates the portfolio max.
  if ("SnapshotDate" %in% colnames(dfResults)) {
    dfResults <- dfResults %>%
      dplyr::group_by(.data$StudyID) %>%
      dplyr::filter(.data$SnapshotDate == max(.data$SnapshotDate, na.rm = TRUE)) %>%
      dplyr::ungroup()
  }

  # Filter to specified group level
  group_results <- dfResults %>%
    dplyr::filter(.data$GroupLevel == strGroupLevel)

  if (nrow(group_results) == 0) {
    stop(paste("No data found for GroupLevel:", strGroupLevel))
  }

  # Per-study totals: collapse Site-level rows up to one row per (StudyID, MetricID).
  per_study <- group_results %>%
    dplyr::group_by(.data$StudyID, .data$MetricID) %>%
    dplyr::summarise(
      Numerator = sum(.data$Numerator, na.rm = TRUE),
      Denominator = sum(.data$Denominator, na.rm = TRUE),
      .groups = "drop"
    )

  # Portfolio total row (one bucket: "Total" across all studies).
  total_summary <- per_study %>%
    dplyr::group_by(.data$MetricID) %>%
    dplyr::summarise(
      Numerator = sum(.data$Numerator, na.rm = TRUE),
      Denominator = sum(.data$Denominator, na.rm = TRUE),
      NumStudies = dplyr::n_distinct(.data$StudyID),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      GroupCategory = "Total",
      GroupValue = "Total",
      Rate = ifelse(
        .data$Denominator > 0,
        .data$Numerator / .data$Denominator,
        NA_real_
      )
    )

  category_summaries <- list(total_summary)

  # Drill-down by study-level params (Q1: all metrics; values come from dfGroups)
  if (
    !is.null(dfGroups) &&
      length(vGroupParams) > 0 &&
      all(c("StudyID", "Param", "Value") %in% colnames(dfGroups))
  ) {
    study_params <- dfGroups %>%
      dplyr::filter(.data$Param %in% vGroupParams) %>%
      dplyr::select("StudyID", "Param", "Value") %>%
      dplyr::distinct()

    for (this_param in vGroupParams) {
      param_rows <- study_params %>%
        dplyr::filter(.data$Param == this_param) %>%
        dplyr::select(StudyID = "StudyID", GroupValue = "Value")

      if (nrow(param_rows) == 0) {
        next
      }

      cat_summary <- per_study %>%
        dplyr::inner_join(param_rows, by = "StudyID") %>%
        dplyr::group_by(.data$GroupValue, .data$MetricID) %>%
        dplyr::summarise(
          Numerator = sum(.data$Numerator, na.rm = TRUE),
          Denominator = sum(.data$Denominator, na.rm = TRUE),
          NumStudies = dplyr::n_distinct(.data$StudyID),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          GroupCategory = this_param,
          Rate = ifelse(
            .data$Denominator > 0,
            .data$Numerator / .data$Denominator,
            NA_real_
          )
        )

      category_summaries[[length(category_summaries) + 1]] <- cat_summary
    }
  }

  out <- dplyr::bind_rows(category_summaries) %>%
    dplyr::select(
      "GroupCategory",
      "GroupValue",
      "MetricID",
      "Numerator",
      "Denominator",
      "Rate",
      "NumStudies"
    ) %>%
    # Q2: sort by MetricID ascending; preserve category order
    dplyr::arrange(
      factor(
        .data$GroupCategory,
        levels = unique(c("Total", vGroupParams, .data$GroupCategory))
      ),
      .data$GroupValue,
      .data$MetricID
    )

  return(out)
}
