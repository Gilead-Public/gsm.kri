test_that("Flag_Duplicates works with wide-format vitals data", {
  df <- data.frame(
    subjid = c("S1", "S1", "S1", "S1", "S2", "S2", "S2"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01",
                       "2024-01-01", "2024-02-01", "2024-03-01")),
    weight = c(75.0, 75.0, 76.0, 75.0, 80.0, 81.0, 80.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  expect_equal(nrow(result), 7)
  expect_true("is_duplicate" %in% names(result))
  expect_true("is_source" %in% names(result))
  expect_type(result$is_duplicate, "integer")
  expect_type(result$is_source, "integer")

  # S1: first=75(0), second=75(1), third=76(0), fourth=75(1)
  s1 <- result[result$subjid == "S1", ]
  expect_equal(s1$is_duplicate, c(0L, 1L, 0L, 1L))
  # S1: first 75 is source (rows 2 and 4 duplicate it), third 76 is not source
  expect_equal(s1$is_source, c(1L, 0L, 0L, 0L))

  # S2: first=80(0), second=81(0), third=80(1)
  s2 <- result[result$subjid == "S2", ]
  expect_equal(s2$is_duplicate, c(0L, 0L, 1L))
  # S2: first 80 is source of the third record
  expect_equal(s2$is_source, c(1L, 0L, 0L))
})

test_that("Flag_Duplicates works with long-format lab data", {
  df <- data.frame(
    subjid = c("S1", "S1", "S1", "S1", "S1", "S1"),
    lb_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01",
                       "2024-01-01", "2024-02-01", "2024-03-01")),
    lbtstnam = c("ALT", "ALT", "ALT", "AST", "AST", "AST"),
    rptresn = c(25, 25, 30, 40, 40, 45)
  )

  result <- Flag_Duplicates(
    df,
    strDateCol = "lb_dt",
    strValueCol = "rptresn",
    strMeasureCol = "lbtstnam",
    strMeasureVal = "ALT"
  )

  # Should only contain ALT rows

  expect_equal(nrow(result), 3)
  expect_equal(result$lbtstnam, c("ALT", "ALT", "ALT"))
  # First=25(0), second=25(1), third=30(0)
  expect_equal(result$is_duplicate, c(0L, 1L, 0L))
  # First 25 is source of second record
  expect_equal(result$is_source, c(1L, 0L, 0L))
})

test_that("Flag_Duplicates handles NA values by excluding them", {
  df <- data.frame(
    subjid = c("S1", "S1", "S1", "S1"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
    weight = c(75.0, NA, 75.0, 76.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  # NA row removed

  expect_equal(nrow(result), 3)
  expect_equal(result$weight, c(75.0, 75.0, 76.0))
  expect_equal(result$is_duplicate, c(0L, 1L, 0L))
  expect_equal(result$is_source, c(1L, 0L, 0L))
})

test_that("Flag_Duplicates handles empty data", {
  df <- data.frame(
    subjid = character(0),
    vs_dt = as.Date(character(0)),
    weight = numeric(0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  expect_equal(nrow(result), 0)
  expect_true("is_duplicate" %in% names(result))
  expect_true("is_source" %in% names(result))
})

test_that("Flag_Duplicates handles single record per subject", {
  df <- data.frame(
    subjid = c("S1", "S2", "S3"),
    vs_dt = as.Date(c("2024-01-01", "2024-01-01", "2024-01-01")),
    weight = c(75.0, 80.0, 85.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  expect_equal(result$is_duplicate, c(0L, 0L, 0L))
  expect_equal(result$is_source, c(0L, 0L, 0L))
})

test_that("Flag_Duplicates first record is never a duplicate", {
  df <- data.frame(
    subjid = c("S1", "S1", "S1"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    weight = c(75.0, 75.0, 75.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  # First is always 0, subsequent matches are 1

  expect_equal(result$is_duplicate, c(0L, 1L, 1L))
  # First record is the source of both duplicates
  expect_equal(result$is_source, c(1L, 0L, 0L))
})

test_that("Flag_Duplicates orders by date correctly", {
  # Provide data out of order
  df <- data.frame(
    subjid = c("S1", "S1", "S1"),
    vs_dt = as.Date(c("2024-03-01", "2024-01-01", "2024-02-01")),
    weight = c(75.0, 76.0, 75.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  # After sorting by date: 76(0), 75(0), 75(1)
  expect_equal(result$vs_dt, as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")))
  expect_equal(result$weight, c(76.0, 75.0, 75.0))
  expect_equal(result$is_duplicate, c(0L, 0L, 1L))
  # Second record (75.0) is source of third (also 75.0)
  expect_equal(result$is_source, c(0L, 1L, 0L))
})

test_that("Flag_Duplicates validates inputs", {
  df <- data.frame(subjid = "S1", vs_dt = Sys.Date(), weight = 75)

  expect_error(Flag_Duplicates(df, strValueCol = "nonexistent"))
  expect_error(Flag_Duplicates(df, strSubjectCol = "bad", strValueCol = "weight"))
  expect_error(Flag_Duplicates(df, strValueCol = "weight", strMeasureCol = "test"))
})

test_that("Flag_Duplicates returns integer is_duplicate column", {
  df <- data.frame(
    subjid = c("S1", "S1"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01")),
    weight = c(75.0, 75.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")
  expect_type(result$is_duplicate, "integer")
  expect_true(is.numeric(result$is_duplicate))
  expect_type(result$is_source, "integer")
  expect_true(is.numeric(result$is_source))
})

test_that("Flag_Duplicates is_source identifies earliest prior matching record", {
  # S1: 70, 75, 70, 75 -> is_dup: 0,0,1,1; is_source: 1(70),1(75),0,0
  df <- data.frame(
    subjid = c("S1", "S1", "S1", "S1"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
    weight = c(70.0, 75.0, 70.0, 75.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  expect_equal(result$is_duplicate, c(0L, 0L, 1L, 1L))
  expect_equal(result$is_source, c(1L, 1L, 0L, 0L))
})

test_that("Flag_Duplicates is_source is not set when no duplicates exist", {
  df <- data.frame(
    subjid = c("S1", "S1", "S2", "S2"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01", "2024-02-01")),
    weight = c(70.0, 75.0, 80.0, 85.0)
  )

  result <- Flag_Duplicates(df, strValueCol = "weight")

  expect_equal(result$is_duplicate, c(0L, 0L, 0L, 0L))
  expect_equal(result$is_source, c(0L, 0L, 0L, 0L))
})
