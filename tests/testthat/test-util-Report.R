test_that("[ FilterByFlags ] returns group/metric combinations with a flag at any snapshot.", {
  dfResultsFlaggedActual <- FilterByFlags(gsm.core::reportingResults)

  strRiskSignals <- gsm.core::reportingResults %>%
    filter(
      .data$Flag != 0
    ) %>%
    mutate(
      riskSignalID = paste(.data$GroupID, .data$MetricID, sep = "_")
    ) %>%
    distinct(
      riskSignalID
    ) %>%
    pull(
      riskSignalID
    )

  dfResultsFlaggedExpected <- gsm.core::reportingResults %>%
    filter(
      paste(.data$GroupID, .data$MetricID, sep = "_") %in% strRiskSignals
    ) %>%
    as_tibble()

  expect_equal(
    dfResultsFlaggedActual,
    dfResultsFlaggedExpected
  )
})

test_that("[ FilterByFlags ] returns group/metric combinations with a flag at most recent snapshot.", {
  dfResultsFlaggedActual <- FilterByFlags(
    gsm.core::reportingResults,
    bCurrentlyFlagged = TRUE
  )

  strRiskSignals <- gsm.core::reportingResults %>%
    FilterByLatestSnapshotDate() %>%
    filter(
      .data$Flag != 0
    ) %>%
    mutate(
      riskSignalID = paste(.data$GroupID, .data$MetricID, sep = "_")
    ) %>%
    distinct(
      riskSignalID
    ) %>%
    pull(
      riskSignalID
    )

  dfResultsFlaggedExpected <- gsm.core::reportingResults %>%
    filter(
      paste(.data$GroupID, .data$MetricID, sep = "_") %in% strRiskSignals
    ) %>%
    as_tibble()

  expect_equal(
    dfResultsFlaggedActual,
    dfResultsFlaggedExpected
  )
})
