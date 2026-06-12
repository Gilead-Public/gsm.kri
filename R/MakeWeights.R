#' Create Weight Table from Metrics Metadata
#'
#' Generates a weight table by parsing comma-separated Flag and RiskScoreWeight values
#' from a metrics metadata data frame. This table can be joined to KRI results to add
#' weight information for risk score calculations.
#'
#' @param dfMetrics `data.frame` Metrics metadata containing at least `MetricID`, `Flag`,
#'   and `RiskScoreWeight` columns. The `Flag` and `RiskScoreWeight` columns should contain
#'   comma-separated values that will be parsed into individual rows. If an `Active` column
#'   is present, rows where `Active == FALSE` are excluded before processing.
#'
#' @return `data.frame` Weight table with one row per MetricID-Flag combination, containing:
#'   \describe{
#'     \item{MetricID}{Unique metric identifier}
#'     \item{Flag}{Individual flag value (numeric)}
#'     \item{Weight}{Weight associated with the flag (numeric)}
#'     \item{WeightMax}{Maximum weight for the metric (numeric)}
#'   }
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Filters to rows with non-NA Flag and RiskScoreWeight values
#'   \item Splits comma-separated Flag and RiskScoreWeight strings into lists
#'   \item Expands to one row per flag-weight combination
#'   \item Converts Flag and Weight to numeric values
#'   \item Calculates WeightMax as the maximum Weight per MetricID
#' }
#'
#' @examples
#' # Create weight table from gsm.core::reportingMetrics
#' dfWeights <- MakeWeights(gsm.core::reportingMetrics)
#'
#' # Join to KRI results
#' library(dplyr)
#' dfResults <- gsm.core::reportingResults %>%
#'   left_join(dfWeights, by = c("MetricID", "Flag"))
#'
#' @export
MakeWeights <- function(dfMetrics) {
  # Input validation
  required_cols <- c("MetricID", "Flag", "RiskScoreWeight")
  if (!all(required_cols %in% colnames(dfMetrics))) {
    missing_cols <- required_cols[!required_cols %in% colnames(dfMetrics)]
    stop(
      "Missing required columns in dfMetrics: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Exclude inactive metrics if the Active column is present
  if ("Active" %in% colnames(dfMetrics)) {
    dfMetrics <- dfMetrics %>%
      dplyr::filter(is.na(.data$Active) | .data$Active != FALSE)
  }

  # Create weight table from dfMetrics
  weight_table <- dfMetrics %>%
    dplyr::filter(!is.na(.data$Flag) & !is.na(.data$RiskScoreWeight)) %>%
    dplyr::select("MetricID", "Flag", "RiskScoreWeight")

  # Return empty data frame with correct structure if no valid rows
  if (nrow(weight_table) == 0) {
    warning(
      "No valid rows found in dfMetrics with non-NA Flag and RiskScoreWeight values. Returning dfWeights data.frame with 0 rows."
    )
    return(data.frame(
      MetricID = character(0),
      Flag = numeric(0),
      Weight = numeric(0),
      WeightMax = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  weight_table <- weight_table %>%
    # Parse the comma-separated Flag and RiskScoreWeight values
    dplyr::mutate(
      flags_list = strsplit(.data$Flag, ","),
      weights_list = strsplit(.data$RiskScoreWeight, ",")
    )

  # Check that flags_list and weights_list have the same length for each metric
  length_check <- weight_table %>%
    dplyr::mutate(
      n_flags = sapply(.data$flags_list, length),
      n_weights = sapply(.data$weights_list, length),
      length_mismatch = .data$n_flags != .data$n_weights
    )

  if (any(length_check$length_mismatch)) {
    mismatched_metrics <- length_check %>%
      dplyr::filter(.data$length_mismatch) %>%
      dplyr::select("MetricID", "n_flags", "n_weights")

    error_details <- paste(
      apply(mismatched_metrics, 1, function(row) {
        glue::glue(
          "  - {row['MetricID']}: {row['n_flags']} flags vs {row['n_weights']} weights"
        )
      }),
      collapse = "\n"
    )

    stop(
      glue::glue(
        "Flag and RiskScoreWeight lists must have the same length for each MetricID. ",
        "Mismatched metrics:\n{error_details}"
      )
    )
  }

  weight_table <- weight_table %>%
    # Expand to one row per flag-weight combination
    tidyr::unnest_longer(c("flags_list", "weights_list")) %>%
    dplyr::mutate(
      Flag = as.numeric(.data$flags_list),
      Weight = as.numeric(.data$weights_list)
    ) %>%
    # Calculate WeightMax by metric
    dplyr::group_by(.data$MetricID) %>%
    dplyr::mutate(WeightMax = max(.data$Weight, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    # Keep only the necessary columns
    dplyr::select("MetricID", "Flag", "Weight", "WeightMax")

  return(weight_table)
}
