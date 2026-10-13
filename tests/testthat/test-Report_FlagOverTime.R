test_that("Report_FlagOverTime returns the expected object", {
  dfResults <- gsm.core::reportingResults %>%
    # Use a subset to keep things fast.
    dplyr::filter(
      .data$MetricID %in% c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003")
    ) %>%
    dplyr::mutate(
      # Rewind the dates so we span 2 years.
      SnapshotDate = .data$SnapshotDate %>%
        lubridate::ymd() %>%
        lubridate::rollbackward() %>%
        lubridate::rollbackward()
    )
  dfMetrics <- gsm.core::reportingMetrics
  x <- Report_FlagOverTime(dfResults, dfMetrics)
  expect_s3_class(x, "gt_tbl")
  expect_snapshot({
    x$`_data`
  })
})
