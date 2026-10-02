# Renders a three-metric site report from the bundled example data and returns
# the metric headers of the Results section, in page order. `lActive` sets the
# Active flag per MetricID; NULL drops the column, as in data that predate it.
kri_report_headers <- function(lActive) {
  skip_if_not(rmarkdown::pandoc_available())
  ids <- paste0("Analysis_", c("kri0001", "kri0006", "kri0008"))
  keep <- function(df) df[df$MetricID %in% ids, ]
  dfMetrics <- keep(gsm.core::reportingMetrics)
  dfResults <- keep(gsm.core::reportingResults)
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
      dfBounds = keep(gsm.core::reportingBounds)
    ),
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    strOutputDir = strOutputDir,
    strOutputFile = "report.html"
  ))
  html <- paste(
    readLines(file.path(strOutputDir, "report.html"), warn = FALSE),
    collapse = "\n"
  )
  results <- sub("(?s).*id=\"results\"", "", html, perl = TRUE)
  headers <- stringr::str_match_all(results, "(?s)<h3>(.*?)</h3>")[[1]][, 2]
  stringr::str_squish(headers)
}

test_that("KRI report lists an inactive metric last and labels it Inactive (#325)", {
  headers <- kri_report_headers(c(
    Analysis_kri0001 = FALSE,
    Analysis_kri0006 = NA,
    Analysis_kri0008 = TRUE
  ))

  expect_equal(headers[1:2], c("Study Discontinuation Rate", "Query Rate"))
  expect_match(
    headers[[3]],
    "^Adverse Event Rate <span class=\"metric-inactive\"[^>]*>Inactive</span>$"
  )
  expect_length(headers, 3)
})

test_that("KRI report keeps the metric order and adds no label without an Active column (#325)", {
  expect_equal(
    kri_report_headers(NULL),
    c("Adverse Event Rate", "Study Discontinuation Rate", "Query Rate")
  )
})
