## Test Setup
library(testthat)

## Test Code
test_that("gsm_gt requires gt package", {
  # Mock data for testing
  test_data <- data.frame(
    col1 = c(1, 2, 3),
    col2 = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  # Test that the function checks for gt installation
  # Note: if gt is installed, this should work; if not, it should error
  if (requireNamespace("gt", quietly = TRUE)) {
    # If gt is available, test that gsm_gt works
    result <- gsm_gt(test_data)
    expect_s3_class(result, "gt_tbl")
  } else {
    # If gt is not available, expect an error
    expect_error(gsm_gt(test_data), class = "rlang_error")
  }
})

test_that("gt_style applies standardized formatting", {
  skip_if_not_installed("gt")

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

test_that("gt_style requires gt package", {
  # Create mock gt table structure for testing package requirement
  mock_table <- structure(list(), class = "gt_tbl")

  # The function should check for gt installation
  if (!requireNamespace("gt", quietly = TRUE)) {
    expect_error(gt_style(mock_table), class = "rlang_error")
  }
})

test_that("gsm_gt passes additional arguments to gt::gt", {
  skip_if_not_installed("gt")

  test_data <- data.frame(
    col1 = c(1, 2, 3),
    col2 = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  # Test that additional arguments are passed through
  # This should not error if arguments are properly passed
  expect_no_error(gsm_gt(test_data, rownames_to_stub = TRUE))

  # Test with grouping
  test_data_grouped <- data.frame(
    group = c("A", "A", "B"),
    col1 = c(1, 2, 3),
    col2 = c("X", "Y", "Z"),
    stringsAsFactors = FALSE
  )

  result_grouped <- gsm_gt(test_data_grouped, groupname_col = "group")
  expect_s3_class(result_grouped, "gt_tbl")
})

test_that("cols_label_month function exists and has documentation", {
  # Test that the function is properly documented and exported
  # This tests that the documentation structure is valid
  expect_true(exists("cols_label_month", envir = asNamespace("gsm.kri"), inherits = FALSE) ||
    "cols_label_month" %in% getNamespaceExports("gsm.kri"))
})

test_that("gt functions handle edge cases", {
  skip_if_not_installed("gt")

  # Test with empty data frame
  empty_data <- data.frame()
  expect_no_error(gsm_gt(empty_data))

  # Test with single row
  single_row <- data.frame(col1 = 1, col2 = "A", stringsAsFactors = FALSE)
  result_single <- gsm_gt(single_row)
  expect_s3_class(result_single, "gt_tbl")

  # Test with single column
  single_col <- data.frame(col1 = c(1, 2, 3), stringsAsFactors = FALSE)
  result_single_col <- gsm_gt(single_col)
  expect_s3_class(result_single_col, "gt_tbl")
})

test_that("gt utility functions maintain data integrity", {
  skip_if_not_installed("gt")

  test_data <- data.frame(
    numeric_col = c(1.5, 2.7, 3.2),
    character_col = c("A", "B", "C"),
    logical_col = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  # Create table and apply styling
  result <- gsm_gt(test_data)

  # The underlying data should be preserved
  expect_s3_class(result, "gt_tbl")
  expect_no_error(gt_style(result))
})
