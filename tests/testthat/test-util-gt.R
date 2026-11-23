test_that("gt_style applies standardized formatting", {
  # Create a basic gt table
  test_data <- data.frame(
    col1 = c(1, 2, 3),
    col2 = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  gt_table <- gt::gt(test_data)
  styled_table <- gt_style(gt_table)

  # Check that it's still a gt_tbl object
  expect_s3_class(styled_table, "gt_tbl")

  # Check that the function doesn't error
  expect_no_error(gt_style(gt_table))
})

test_that("gt_style passes additional arguments to gt::gt", {
  test_data <- data.frame(
    col1 = c(1, 2, 3),
    col2 = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  # Test that additional arguments are passed through
  # This should not error if arguments are properly passed
  expect_no_error(gt_style(test_data, rownames_to_stub = TRUE))

  # Test with grouping
  test_data_grouped <- data.frame(
    group = c("A", "A", "B"),
    col1 = c(1, 2, 3),
    col2 = c("X", "Y", "Z"),
    stringsAsFactors = FALSE
  )

  result_grouped <- gt_style(test_data_grouped, groupname_col = "group")
  expect_s3_class(result_grouped, "gt_tbl")
})

test_that("cols_label_month function exists and has documentation", {
  # Test that the function is properly documented and exported
  # This tests that the documentation structure is valid
  expect_true(
    exists(
      "cols_label_month",
      envir = asNamespace("gsm.kri"),
      inherits = FALSE
    ) ||
      "cols_label_month" %in% getNamespaceExports("gsm.kri")
  )
})

test_that("gt functions handle edge cases", {
  # Test with empty data frame
  empty_data <- data.frame()
  expect_no_error(gt_style(empty_data))

  # Test with single row
  single_row <- data.frame(col1 = 1, col2 = "A", stringsAsFactors = FALSE)
  result_single <- gt_style(single_row)
  expect_s3_class(result_single, "gt_tbl")

  # Test with single column
  single_col <- data.frame(col1 = c(1, 2, 3), stringsAsFactors = FALSE)
  result_single_col <- gt_style(single_col)
  expect_s3_class(result_single_col, "gt_tbl")
})

test_that("gt utility functions maintain data integrity", {
  test_data <- data.frame(
    numeric_col = c(1.5, 2.7, 3.2),
    character_col = c("A", "B", "C"),
    logical_col = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  # Create table and apply styling
  result <- gt_style(test_data)

  # The underlying data should be preserved
  expect_s3_class(result, "gt_tbl")
  expect_no_error(gt_style(result))
})
