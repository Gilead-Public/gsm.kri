test_that("Widget_RecordDuplication creates a valid htmlwidget", {
  dfFlagged <- data.frame(
    subjid = c("S001", "S001", "S001", "S002", "S002"),
    GroupID = c("SITE01", "SITE01", "SITE01", "SITE01", "SITE01"),
    date = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-01-01", "2024-02-01")),
    measure = c("weight", "weight", "weight", "weight", "weight"),
    value = c(75, 75, 75, 80, 80),
    RunID = c(1L, 1L, 1L, 1L, 1L),
    RunLength = c(3L, 3L, 3L, 2L, 2L),
    IsRepeatRun = c(1L, 1L, 1L, 0L, 0L),
    IsEvaluableWindow = c(0L, 0L, 1L, 0L, 0L),
    IsRepeatWindow = c(0L, 0L, 1L, 0L, 0L),
    stringsAsFactors = FALSE
  )

  w <- Widget_RecordDuplication(dfFlagged)

  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "Widget_RecordDuplication")
})

test_that("Widget_RecordDuplication accepts new metric parameters", {
  dfFlagged <- data.frame(
    subjid = c("S001", "S001"),
    GroupID = c("SITE01", "SITE01"),
    date = as.Date(c("2024-01-01", "2024-02-01")),
    measure = c("weight", "weight"),
    value = c(75, 75),
    RunID = c(1L, 1L),
    RunLength = c(2L, 2L),
    IsRepeatRun = c(0L, 0L),
    IsEvaluableWindow = c(0L, 0L),
    IsRepeatWindow = c(0L, 0L),
    stringsAsFactors = FALSE
  )

  dfReportingResults <- data.frame(
    GroupID = "SITE01",
    GroupLevel = "Site",
    MetricID = "Analysis_kri0016",
    Score = 2.34,
    Flag = 2L,
    stringsAsFactors = FALSE
  )

  dfMeasureMetrics <- data.frame(
    measure = "weight",
    MetricID = "Analysis_kri0016",
    stringsAsFactors = FALSE
  )

  w <- Widget_RecordDuplication(
    dfFlagged,
    dfReportingResults = dfReportingResults,
    dfMeasureMetrics = dfMeasureMetrics
  )

  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "Widget_RecordDuplication")
})

test_that("Widget_RecordDuplication validates inputs", {
  expect_error(Widget_RecordDuplication(data.frame(x = 1)))
})

test_that("Report_RecordDuplication produces widget from vitals data", {
  set.seed(123)
  Mapped_SUBJ <- data.frame(
    subjid = paste0("S", 1:10),
    invid = rep(c("SITE01", "SITE02"), each = 5),
    stringsAsFactors = FALSE
  )

  Mapped_VS <- data.frame(
    subjid = rep(paste0("S", 1:10), each = 5),
    vs_dt = rep(as.Date("2024-01-01") + (0:4) * 30, 10),
    weight = c(rep(75.0, 5), round(rnorm(45, 75, 10), 1)),
    stringsAsFactors = FALSE
  )

  w <- Report_RecordDuplication(
    dfMappedVS = Mapped_VS,
    dfMappedSUBJ = Mapped_SUBJ,
    vPrioritizedMeasures = c("weight")
  )

  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "Widget_RecordDuplication")
})

test_that("Report_RecordDuplication handles empty data", {
  Mapped_SUBJ <- data.frame(
    subjid = "S1",
    invid = "SITE01",
    stringsAsFactors = FALSE
  )

  Mapped_VS <- data.frame(
    subjid = character(0),
    vs_dt = as.Date(character(0)),
    weight = numeric(0),
    stringsAsFactors = FALSE
  )

  w <- Report_RecordDuplication(
    dfMappedVS = Mapped_VS,
    dfMappedSUBJ = Mapped_SUBJ
  )

  expect_s3_class(w, "htmlwidget")
})

test_that("Report_RecordDuplication carries the window columns through", {
  Mapped_SUBJ <- data.frame(
    subjid = c("S1", "S2"),
    invid = "SITE01",
    stringsAsFactors = FALSE
  )

  # S1 has a run of 4 identical weights; S2 varies.
  Mapped_VS <- data.frame(
    subjid = rep(c("S1", "S2"), each = 5),
    vs_dt = rep(as.Date("2024-01-01") + (0:4) * 30, 2),
    weight = c(70, 75, 75, 75, 75, 80, 81, 82, 83, 84),
    stringsAsFactors = FALSE
  )

  w <- Report_RecordDuplication(
    dfMappedVS = Mapped_VS,
    dfMappedSUBJ = Mapped_SUBJ,
    vMeasuresVS = "weight",
    nWindowLength = 3
  )

  dfFlagged <- jsonlite::fromJSON(w$x$dfFlagged)

  expect_equal(sum(dfFlagged$IsRepeatWindow), 2)
  expect_equal(sum(dfFlagged$IsEvaluableWindow), 6)
  # The whole run is highlighted, not just the windows that close inside it.
  expect_equal(sum(dfFlagged$IsRepeatRun), 4)
})

test_that("Report_RecordDuplication honors nWindowLength", {
  Mapped_SUBJ <- data.frame(subjid = "S1", invid = "SITE01", stringsAsFactors = FALSE)
  Mapped_VS <- data.frame(
    subjid = rep("S1", 5),
    vs_dt = as.Date("2024-01-01") + (0:4) * 30,
    weight = c(70, 75, 75, 80, 81),
    stringsAsFactors = FALSE
  )

  wNarrow <- Report_RecordDuplication(
    dfMappedVS = Mapped_VS, dfMappedSUBJ = Mapped_SUBJ,
    vMeasuresVS = "weight", nWindowLength = 2
  )
  wWide <- Report_RecordDuplication(
    dfMappedVS = Mapped_VS, dfMappedSUBJ = Mapped_SUBJ,
    vMeasuresVS = "weight", nWindowLength = 3
  )

  expect_equal(sum(jsonlite::fromJSON(wNarrow$x$dfFlagged)$IsRepeatWindow), 1)
  expect_equal(sum(jsonlite::fromJSON(wWide$x$dfFlagged)$IsRepeatWindow), 0)
})
