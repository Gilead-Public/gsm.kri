## Test Setup
library(testthat)

## Test Code
test_that("pipe operator is properly exported", {
  # Test that the pipe operator is available
  expect_true("%>%" %in% getNamespaceExports("gsm.kri"))

  # Test that it works as expected (basic functionality)
  result <- c(1, 2, 3) %>% sum()
  expect_equal(result, 6)

  # Test with data.frame
  test_df <- data.frame(x = 1:3, y = 4:6)
  result_df <- test_df %>% nrow()
  expect_equal(result_df, 3)
})

test_that("pipe operator works with gsm.kri functions", {
  # Create test data
  test_data <- data.frame(
    GroupID = c("Site1", "Site2"),
    Value = c(10, 20),
    stringsAsFactors = FALSE
  )

  # Test pipe with a gsm.kri function (if available)
  # This is a basic test to ensure the pipe works in the context of the package
  result <- test_data %>%
    dplyr::mutate(NewCol = Value * 2) %>%
    nrow()

  expect_equal(result, 2)
})

test_that("pipe operator maintains magrittr functionality", {
  # Test various magrittr pipe features work correctly

  # Basic piping
  result1 <- 1:10 %>% sum()
  expect_equal(result1, 55)

  # Piping with function arguments
  result2 <- c(1, 2, NA, 4) %>% sum(na.rm = TRUE)
  expect_equal(result2, 7)

  # Multiple pipe operations
  result3 <- 1:5 %>%
    `*`(2) %>%
    sum()
  expect_equal(result3, 30)

  # Pipe with data frames
  df_result <- data.frame(a = 1:3, b = 4:6) %>%
    transform(c = a + b) %>%
    nrow()
  expect_equal(df_result, 3)
})
