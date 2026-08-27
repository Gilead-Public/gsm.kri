#' Summarize Site Risk Score Weighting
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates a user-facing explanation and table showing how each metric's flag
#' weights contribute to the normalized Site Risk Score (SRS).
#'
#' @param dfMetrics `data.frame` Metrics metadata containing `MetricID`, `Flag`,
#'   and `RiskScoreWeight`. When available, `Metric` supplies the display label
#'   and inactive metrics are excluded.
#' @param dfResults Optional `data.frame` of results used to calculate the SRS.
#'   When supplied, the summary includes only metrics present in these results.
#'
#' @return An [htmltools::tagList()] containing explanatory text and a formatted
#'   weighting table.
#'
#' @examples
#' Report_SRSWeighting(gsm.core::reportingMetrics)
#'
#' @export
Report_SRSWeighting <- function(dfMetrics, dfResults = NULL) {
  dfWeights <- MakeWeights(dfMetrics)

  if (!is.null(dfResults)) {
    if (!is.data.frame(dfResults) || !"MetricID" %in% names(dfResults)) {
      stop("dfResults must be a data frame containing a 'MetricID' column.")
    }
    dfWeights <- dfWeights[dfWeights$MetricID %in% dfResults$MetricID, ]
  }

  if (any(duplicated(dfWeights[c("MetricID", "Flag")]))) {
    stop("The combination of 'MetricID' and 'Flag' must be unique in dfMetrics.")
  }

  vMetricIDs <- unique(dfMetrics$MetricID[dfMetrics$MetricID %in% dfWeights$MetricID])
  vFlags <- sort(unique(dfWeights$Flag))

  metric_label <- function(strMetricID) {
    intRow <- match(strMetricID, dfMetrics$MetricID)
    if (
      "Metric" %in% names(dfMetrics) &&
        !is.na(dfMetrics$Metric[intRow]) &&
        nzchar(dfMetrics$Metric[intRow])
    ) {
      return(dfMetrics$Metric[intRow])
    }
    strMetricID
  }

  format_number <- function(x) {
    format(x, trim = TRUE, scientific = FALSE)
  }

  flag_label <- function(x) {
    labels <- c(
      `-2` = "Low red (-2)",
      `-1` = "Low amber (-1)",
      `0` = "Not flagged (0)",
      `1` = "High amber (+1)",
      `2` = "High red (+2)"
    )
    strFlag <- format_number(x)
    if (strFlag %in% names(labels)) {
      return(labels[[strFlag]])
    }
    paste("Flag", if (x > 0) paste0("+", strFlag) else strFlag)
  }

  vMaxWeights <- vapply(vMetricIDs, function(strMetricID) {
    unique(dfWeights$WeightMax[dfWeights$MetricID == strMetricID])
  }, numeric(1))
  nTotalPossible <- sum(vMaxWeights)

  lHeader <- c(
    list(htmltools::tags$th(scope = "col", "Metric")),
    lapply(vFlags, function(nFlag) {
      htmltools::tags$th(scope = "col", flag_label(nFlag))
    }),
    list(
      htmltools::tags$th(scope = "col", "Maximum contribution"),
      htmltools::tags$th(scope = "col", "Share of total possible SRS")
    )
  )

  lRows <- lapply(seq_along(vMetricIDs), function(i) {
    strMetricID <- vMetricIDs[[i]]
    lWeightCells <- lapply(vFlags, function(nFlag) {
      vWeight <- dfWeights$Weight[
        dfWeights$MetricID == strMetricID & dfWeights$Flag == nFlag
      ]
      if (length(vWeight) == 0) {
        return(htmltools::tags$td(
          class = "srs-weighting-not-configured",
          "Not configured"
        ))
      }
      htmltools::tags$td(format_number(vWeight))
    })

    strShare <- if (nTotalPossible > 0) {
      sprintf("%.1f%%", vMaxWeights[[i]] / nTotalPossible * 100)
    } else {
      "Not available"
    }

    htmltools::tags$tr(
      htmltools::tags$th(scope = "row", metric_label(strMetricID)),
      lWeightCells,
      htmltools::tags$td(
        class = "srs-weighting-maximum",
        paste(format_number(vMaxWeights[[i]]), "points")
      ),
      htmltools::tags$td(class = "srs-weighting-share", strShare)
    )
  })

  htmltools::tagList(
    htmltools::tags$style(htmltools::HTML(
      ".srs-weighting-summary{color:#333}.srs-weighting-summary p{max-width:80rem}",
      ".srs-weighting-table-wrap{overflow-x:auto;margin:1rem 0}",
      ".srs-weighting-table{border-collapse:collapse;width:100%;font-size:0.95em}",
      ".srs-weighting-table caption{text-align:left;font-weight:bold;margin-bottom:.5rem}",
      ".srs-weighting-table th,.srs-weighting-table td{border:1px solid #d8d8d8;padding:.55rem .7rem;text-align:center}",
      ".srs-weighting-table thead th{background:#3c587f;color:white;vertical-align:bottom}",
      ".srs-weighting-table tbody th{text-align:left;background:#f5f5f5}",
      ".srs-weighting-table tbody tr:nth-child(even) td{background:#fafafa}",
      ".srs-weighting-maximum,.srs-weighting-share{font-weight:bold}",
      ".srs-weighting-not-configured{color:#666;font-style:italic}"
    )),
    htmltools::tags$section(
      class = "srs-weighting-summary",
      htmltools::tags$h3("How metric weighting contributes to the Site Risk Score"),
      htmltools::tags$p(paste0(
        "Each metric assigns points according to the site's flag. ",
        "The points for all metrics are added together, then divided by the ",
        "total possible points and multiplied by 100 to produce the normalized SRS."
      )),
      htmltools::tags$p(
        "The maximum contribution is the largest configured weight for a metric. ",
        "Its share shows how much that metric can contribute to the total possible SRS. ",
        htmltools::tags$strong(
          paste("Total possible points:", format_number(nTotalPossible))
        )
      ),
      htmltools::tags$div(
        class = "srs-weighting-table-wrap",
        htmltools::tags$table(
          class = "srs-weighting-table",
          htmltools::tags$caption("Metric weights used in the Site Risk Score"),
          htmltools::tags$thead(htmltools::tags$tr(lHeader)),
          htmltools::tags$tbody(lRows)
        )
      )
    )
  )
}
