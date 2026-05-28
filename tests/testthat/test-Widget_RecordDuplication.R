test_that("Widget_RecordDuplication creates a valid htmlwidget", {
  dfFlagged <- data.frame(
    subjid = c("S001", "S001", "S001", "S002", "S002"),
    GroupID = c("SITE01", "SITE01", "SITE01", "SITE01", "SITE01"),
    date = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-01-01", "2024-02-01")),
    measure = c("weight", "weight", "weight", "weight", "weight"),
    value = c(75, 75, 76, 80, 80),
    is_duplicate = c(0L, 1L, 0L, 0L, 1L),
    stringsAsFactors = FALSE
  )

  w <- Widget_RecordDuplication(dfFlagged)

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
