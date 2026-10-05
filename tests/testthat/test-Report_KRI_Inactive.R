kri_ids <- paste0("Analysis_", c("kri0001", "kri0006", "kri0008"))
kri_keep <- function(df) df[df$MetricID %in% kri_ids, ]

# Renders a three-metric site report from the bundled example data and returns
# its HTML. `lActive` sets the Active flag per MetricID; NULL drops the column,
# as in data that predate it.
render_kri_report <- function(
  lActive,
  dfResults = kri_keep(gsm.core::reportingResults)
) {
  skip_if_not(rmarkdown::pandoc_available())
  dfMetrics <- kri_keep(gsm.core::reportingMetrics)
  dfMetrics$Active <- if (is.null(lActive)) {
    NULL
  } else {
    unname(lActive[dfMetrics$MetricID])
  }

  strOutputDir <- withr::local_tempdir()
  suppressMessages(Report_KRI(
    lCharts = MakeCharts(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = gsm.core::reportingGroups,
      dfBounds = kri_keep(gsm.core::reportingBounds)
    ),
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    strOutputDir = strOutputDir,
    strOutputFile = "report.html"
  ))
  paste(
    readLines(file.path(strOutputDir, "report.html"), warn = FALSE),
    collapse = "\n"
  )
}

# Metric headers of the Results section, in page order.
kri_report_headers <- function(html) {
  results <- sub("(?s).*id=\"results\"", "", html, perl = TRUE)
  headers <- stringr::str_match_all(results, "(?s)<h3>(.*?)</h3>")[[1]][, 2]
  stringr::str_squish(headers)
}

test_that("KRI report lists an inactive metric last and labels it Inactive (#325)", {
  headers <- kri_report_headers(render_kri_report(c(
    Analysis_kri0001 = FALSE,
    Analysis_kri0006 = NA,
    Analysis_kri0008 = TRUE
  )))

  expect_equal(headers[1:2], c("Study Discontinuation Rate", "Query Rate"))
  expect_match(
    headers[[3]],
    "^Adverse Event Rate <span class=\"metric-inactive\"[^>]*>Inactive</span>$"
  )
  expect_length(headers, 3)
})

test_that("KRI report keeps the metric order and adds no label without an Active column (#325)", {
  expect_equal(
    kri_report_headers(render_kri_report(NULL)),
    c("Adverse Event Rate", "Study Discontinuation Rate", "Query Rate")
  )
})

test_that("KRI report keeps the time series of earlier snapshots for an inactive metric missing from the latest snapshot (#325)", {
  # kri0001, not kri0007: bundled kri0007 results carry no Score to plot.
  dfResults <- kri_keep(gsm.core::reportingResults)
  dateLatest <- max(dfResults$SnapshotDate)
  dfResults <- dfResults[
    !(dfResults$MetricID == "Analysis_kri0001" &
      dfResults$SnapshotDate == dateLatest),
  ]

  # Charts of the latest snapshot warn that kri0001 has no data there.
  html <- suppressWarnings(render_kri_report(
    c(
      Analysis_kri0001 = FALSE,
      Analysis_kri0006 = TRUE,
      Analysis_kri0008 = TRUE
    ),
    dfResults
  ))

  expect_match(
    tail(kri_report_headers(html), 1),
    "^Adverse Event Rate <span class=\"metric-inactive\""
  )
  mWidgets <- stringr::str_match_all(
    html,
    "gsm-widget Analysis_kri0001 (\\w+)\""
  )
  expect_equal(mWidgets[[1]][, 2], "timeSeries")
  strPayload <- stringr::str_match(
    html,
    "(?s)gsm-widget Analysis_kri0001 timeSeries\".*?<script type=\"application/json\"[^>]*>(.*?)</script>"
  )[, 2]
  dfPlotted <- jsonlite::fromJSON(strPayload)$x$dfResults
  expect_setequal(
    unique(dfPlotted$SnapshotDate[!is.na(dfPlotted$Score)]),
    setdiff(
      as.character(unique(dfResults$SnapshotDate)),
      as.character(dateLatest)
    )
  )
})
