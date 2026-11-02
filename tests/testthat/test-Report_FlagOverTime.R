test_that("Report_FlagOverTime returns the expected object", {
  strMetrics <- c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003")
  dfSubset <- gsm.core::reportingResults %>%
    dplyr::filter(
      .data$GroupLevel == "Site",
      .data$MetricID %in% strMetrics,
      SnapshotDate > "2025-02-01",
      SnapshotDate < "2025-05-01"
    )
  # Choose sites from the data (not hard-coded IDs) so a data refresh can't
  # silently empty the table. Require a scored flag in every snapshot (NA
  # would otherwise count as a "change"), then prefer sites whose flags change.
  strGroups <- dfSubset %>%
    dplyr::summarise(
      bComplete = dplyr::n_distinct(.data$SnapshotDate[!is.na(.data$Flag)]) ==
        dplyr::n_distinct(dfSubset$SnapshotDate),
      nFlags = dplyr::n_distinct(.data$Flag),
      .by = "GroupID"
    ) %>%
    dplyr::filter(.data$bComplete) %>%
    dplyr::arrange(dplyr::desc(.data$nFlags), .data$GroupID) %>%
    utils::head(3) %>%
    dplyr::pull("GroupID")

  dfResults <- dfSubset %>%
    dplyr::filter(.data$GroupID %in% strGroups) %>%
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
  expect_equal(nrow(x$`_data`), 9)
  expect_snapshot({
    x$`_data`
  })
})
