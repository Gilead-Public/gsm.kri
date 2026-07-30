test_that("Flag_Duplicates marks no duplicates when subject has a single record (#230)", {
  df <- data.frame(
    subjid = "001",
    vs_dt = as.Date("2024-01-01"),
    weight = 72.3
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_identical(result$is_duplicate, FALSE)
})

test_that("Flag_Duplicates marks all but the first record as duplicate when all values are identical (#230)", {
  df <- data.frame(
    subjid = "001",
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    weight = c(72.3, 72.3, 72.3)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_identical(result$is_duplicate, c(FALSE, TRUE, TRUE))
})

test_that("Flag_Duplicates marks no duplicates when all values differ (#230)", {
  df <- data.frame(
    subjid = "001",
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    weight = c(72.3, 73.1, 74.0)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_identical(result$is_duplicate, c(FALSE, FALSE, FALSE))
})

test_that("Flag_Duplicates drops records with NA values and evaluates duplicates on remaining records (#230)", {
  df <- data.frame(
    subjid = c("001", "001", "001", "001"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
    weight = c(72.3, NA, 72.3, 73.1)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_equal(nrow(result), 3)
  expect_identical(result$vs_dt, as.Date(c("2024-01-01", "2024-03-01", "2024-04-01")))
  expect_identical(result$is_duplicate, c(FALSE, TRUE, FALSE))
})

test_that("Flag_Duplicates resolves tied dates by input row order (#230)", {
  df <- data.frame(
    subjid = c("001", "001", "001"),
    vs_dt = as.Date(c("2024-01-01", "2024-01-01", "2024-01-01")),
    weight = c(72.3, 72.3, 73.1)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_identical(result$is_duplicate, c(FALSE, TRUE, FALSE))
})

test_that("Flag_Duplicates tracks previously seen values independently per subject (#230)", {
  df <- data.frame(
    subjid = c("001", "001", "002", "002"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01", "2024-02-01")),
    weight = c(72.3, 72.3, 72.3, 80.0)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_identical(
    result[order(result$subjid, result$vs_dt), "is_duplicate"],
    c(FALSE, TRUE, FALSE, FALSE)
  )
})

test_that("Flag_Duplicates handles wide-format data without a measure column (#230)", {
  df <- data.frame(
    subjid = c("001", "001", "002"),
    vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01")),
    weight = c(72.3, 72.3, 65.0),
    sysbp = c(120, 122, 118)
  )

  result <- Flag_Duplicates(df = df, strValueCol = "weight")

  expect_true("is_duplicate" %in% names(result))
  expect_identical(result$is_duplicate, c(FALSE, TRUE, FALSE))
})

test_that("Flag_Duplicates filters to the specified measure for long-format data (#230)", {
  df <- data.frame(
    subjid = c("001", "001", "001", "001"),
    lb_dt = as.Date(c("2024-01-01", "2024-01-01", "2024-02-01", "2024-02-01")),
    lbtstnam = c("ALT (SGPT)", "AST (SGOT)", "ALT (SGPT)", "AST (SGOT)"),
    rptresn = c(20, 20, 20, 30)
  )

  result <- Flag_Duplicates(
    df = df,
    strValueCol = "rptresn",
    strDateCol = "lb_dt",
    strMeasureCol = "lbtstnam",
    strMeasureVal = "ALT (SGPT)"
  )

  expect_equal(nrow(result), 2)
  expect_true(all(result$lbtstnam == "ALT (SGPT)"))
  expect_identical(result$is_duplicate, c(FALSE, TRUE))
})

test_that("Flag_Duplicates supports non-default subject and date columns (#230)", {
  df <- data.frame(
    participant_id = c("001", "001", "002"),
    collection_date = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01")),
    weight = c(72.3, 72.3, 65.0)
  )

  result <- Flag_Duplicates(
    df = df,
    strValueCol = "weight",
    strSubjectCol = "participant_id",
    strDateCol = "collection_date"
  )

  expect_identical(result$is_duplicate, c(FALSE, TRUE, FALSE))
})
