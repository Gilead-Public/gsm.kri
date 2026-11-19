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

  serialize_number <- function(x) {
    format(
      x,
      digits = 17,
      trim = TRUE,
      scientific = FALSE,
      decimal.mark = "."
    )
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
  lMetricWeights <- lapply(vMetricIDs, function(strMetricID) {
    dfWeights[dfWeights$MetricID == strMetricID, ]
  })
  vDefaultFlags <- vapply(lMetricWeights, function(dfMetricWeights) {
    if (0 %in% dfMetricWeights$Flag) {
      return(0)
    }
    dfMetricWeights$Flag[which.min(dfMetricWeights$Weight)]
  }, numeric(1))
  vDefaultWeights <- vapply(seq_along(lMetricWeights), function(i) {
    dfMetricWeights <- lMetricWeights[[i]]
    dfMetricWeights$Weight[match(vDefaultFlags[[i]], dfMetricWeights$Flag)]
  }, numeric(1))
  nInitialPoints <- sum(vDefaultWeights)
  strInitialSRS <- if (nTotalPossible > 0) {
    sprintf("%.1f", nInitialPoints / nTotalPossible * 100)
  } else {
    "Not available"
  }

  lHeader <- c(
    list(htmltools::tags$th(scope = "col", "Metric")),
    lapply(vFlags, function(nFlag) {
      htmltools::tags$th(scope = "col", flag_label(nFlag))
    }),
    list(
      htmltools::tags$th(scope = "col", "Maximum contribution"),
      htmltools::tags$th(scope = "col", "Share of total possible SRS"),
      htmltools::tags$th(
        class = paste(
          "srs-weighting-example-cell",
          "srs-weighting-calculator-content"
        ),
        hidden = "",
        scope = "col",
        "Selected flag"
      ),
      htmltools::tags$th(
        class = paste(
          "srs-weighting-example-cell",
          "srs-weighting-calculator-content"
        ),
        hidden = "",
        scope = "col",
        "Metric score"
      )
    )
  )
  nReferenceColumns <- length(lHeader) - 2

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
    dfMetricWeights <- lMetricWeights[[i]]
    nDefaultFlag <- vDefaultFlags[[i]]
    nDefaultWeight <- vDefaultWeights[[i]]
    lFlagOptions <- lapply(seq_len(nrow(dfMetricWeights)), function(j) {
      nFlag <- dfMetricWeights$Flag[[j]]
      htmltools::tags$option(
        value = serialize_number(nFlag),
        `data-weight` = serialize_number(dfMetricWeights$Weight[[j]]),
        selected = if (nFlag == nDefaultFlag) "" else NULL,
        flag_label(nFlag)
      )
    })

    htmltools::tags$tr(
      htmltools::tags$th(scope = "row", metric_label(strMetricID)),
      lWeightCells,
      htmltools::tags$td(
        class = "srs-weighting-maximum",
        paste(format_number(vMaxWeights[[i]]), "points")
      ),
      htmltools::tags$td(class = "srs-weighting-share", strShare),
      htmltools::tags$td(
        class = paste(
          "srs-weighting-example-cell",
          "srs-weighting-calculator-content"
        ),
        hidden = "",
        htmltools::tags$select(
          class = "srs-weighting-flag-select",
          `aria-label` = paste("Select flag for", metric_label(strMetricID)),
          lFlagOptions
        )
      ),
      htmltools::tags$td(
        class = paste(
          "srs-weighting-example-cell",
          "srs-weighting-calculator-content"
        ),
        hidden = "",
        htmltools::tags$output(
          class = "srs-weighting-metric-score",
          `aria-live` = "polite",
          paste(format_number(nDefaultWeight), "points")
        )
      )
    )
  })

  lSummary <- htmltools::tagList(
    htmltools::tags$style(htmltools::HTML(
      ".srs-weighting-summary{--srs-example-bg:#e8eef5;color:#333}.srs-weighting-summary p{max-width:80rem}",
      ".srs-weighting-table-wrap{overflow-x:auto;margin:1rem 0}",
      ".srs-weighting-table{border-collapse:collapse;width:100%;font-size:0.95em}",
      ".srs-weighting-table caption{text-align:left;font-weight:bold;margin-bottom:.5rem}",
      ".srs-weighting-table th,.srs-weighting-table td{border:1px solid #d8d8d8;padding:.55rem .7rem;text-align:center}",
      ".srs-weighting-table thead th{background:#3c587f;color:white;vertical-align:bottom}",
      ".srs-weighting-table tbody th{text-align:left;background:#f5f5f5}",
      ".srs-weighting-table tbody tr:nth-child(even) td{background:#fafafa}",
      ".srs-weighting-maximum,.srs-weighting-share{font-weight:bold}",
      ".srs-weighting-not-configured{color:#666;font-style:italic}",
      ".srs-weighting-total-row th{background:var(--srs-example-bg)!important;color:#243b5a!important;font-size:1.1em;text-align:left!important}",
      ".srs-weighting-example-subhead,.srs-weighting-table thead th.srs-weighting-example-cell{background:var(--srs-example-bg)!important;color:#243b5a!important}",
      ".srs-weighting-table tbody tr td.srs-weighting-example-cell{background:var(--srs-example-bg)}",
      ".srs-weighting-total-score{font-size:1.25em}",
      ".srs-weighting-calculator-toggle{background:#3c587f;border:0;border-radius:3px;color:white;cursor:pointer;font-weight:bold;margin:.25rem 0 1rem;padding:.55rem .9rem}",
      ".srs-weighting-calculator-toggle:focus-visible{outline:3px solid #fff;outline-offset:1px;box-shadow:0 0 0 4px #005fcc}",
      ".srs-weighting-flag-select{min-width:10rem;padding:.35rem}",
      ".srs-weighting-metric-score{font-weight:bold;white-space:nowrap}"
    )),
    htmltools::tags$section(
      class = "srs-weighting-summary",
      `data-total-possible` = serialize_number(nTotalPossible),
      htmltools::tags$h3("Site Risk Score Overview"),
      htmltools::tags$p(paste0(
        "Each metric assigns points according to the site's flag. ",
        "The points for all metrics are added together, then divided by the ",
        "total possible points and multiplied by 100 to produce the normalized SRS."
      )),
      htmltools::tags$p(paste0(
        "Each metric's maximum contribution is the highest number of points that ",
        "the metric can add to the SRS, based on its largest configured weight. ",
        "The contribution percentage shows how much of the total possible SRS can ",
        "come from that metric."
      )),
      htmltools::tags$p(
        "Choose a flag for each metric to see its point contribution and calculate an example SRS."
      ),
      htmltools::tags$button(
        class = "srs-weighting-calculator-toggle",
        type = "button",
        `aria-expanded` = "false",
        "Show example SRS calculator"
      ),
      htmltools::tags$div(
        class = "srs-weighting-table-wrap",
        htmltools::tags$table(
          class = "srs-weighting-table",
          htmltools::tags$caption("Metric weights used in the Site Risk Score"),
          htmltools::tags$thead(
            htmltools::tags$tr(
              class = paste(
                "srs-weighting-total-row",
                "srs-weighting-calculator-content"
              ),
              hidden = "",
              htmltools::tags$th(
                colspan = length(lHeader),
                "Example SRS: ",
                htmltools::tags$output(
                  class = "srs-weighting-total-score",
                  `aria-live` = "polite",
                  strInitialSRS
                ),
                " = ",
                htmltools::tags$span(
                  class = "srs-weighting-selected-points",
                  format_number(nInitialPoints)
                ),
                " selected points / ",
                format_number(nTotalPossible),
                " total possible points x 100"
              )
            ),
            htmltools::tags$tr(
              class = "srs-weighting-calculator-content",
              hidden = "",
              htmltools::tags$th(
                class = "srs-weighting-reference-subhead",
                colspan = nReferenceColumns,
                `aria-hidden` = "true"
              ),
              htmltools::tags$th(
                class = paste(
                  "srs-weighting-example-subhead",
                  "srs-weighting-calculator-content"
                ),
                colspan = 2,
                hidden = "",
                scope = "colgroup",
                "Example SRS"
              )
            ),
            htmltools::tags$tr(lHeader)
          ),
          htmltools::tags$tbody(lRows)
        )
      )
    )
  )

  htmltools::attachDependencies(
    lSummary,
    htmltools::htmlDependency(
      name = "srs-weighting",
      version = "1.0.0",
      src = c(
        file = system.file("report", "lib", package = "gsm.kri")
      ),
      script = "srsWeighting.js"
    )
  )
}
