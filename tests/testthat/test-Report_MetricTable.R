test_that("Empty data frames return default message", {
  dfResults_empty <- gsm.core::reportingResults[
    -c(1:nrow(gsm.core::reportingResults)),
  ]
  dfGroups_empty <- gsm.core::reportingGroups[
    -c(1:nrow(gsm.core::reportingGroups)),
  ]
  result <- Report_MetricTable(dfResults_empty, dfGroups_empty)
  expected <- htmltools::tags$p("Nothing flagged for this KRI.")
  expect_equal(as.character(result), as.character(expected))
})

test_that("Default message when nothing flagged", {
  dfResults <- dplyr::filter(
    gsm.core::reportingResults,
    MetricID == "kri0001",
    Flag == 0
  )
  dfGroups <- gsm.core::reportingGroups
  result <- Report_MetricTable(dfResults, dfGroups)
  expected <- htmltools::tags$p("Nothing flagged for this KRI.")
  expect_equal(as.character(result), as.character(expected))
})

test_that("output_label attribute is set even with no flags (Issue #107)", {
  # Create test data with all Flag=0
  dfResults <- dplyr::filter(
    gsm.core::reportingResults,
    MetricID == "kri0001",
    Flag == 0
  )
  dfGroups <- gsm.core::reportingGroups

  # Get result from Report_MetricTable
  result <- Report_MetricTable(dfResults, dfGroups)

  # Check that output_label attribute exists and is not NULL
  output_label <- attr(result, "output_label")
  expect_false(is.null(output_label))
  expect_true(grepl("Metric Table", output_label))
})

test_that("Correct data structure when proper dataframe is passed", {
  reportingResults_filt <- gsm.core::reportingResults %>%
    dplyr::filter(MetricID == "Analysis_kri0001")
  result <- Report_MetricTable(reportingResults_filt, gsm.core::reportingGroups)
  expect_s3_class(result, "gt_tbl")
  expect_true(is.character(result$`_data`$Group))
  expect_true(all(result$`_data`$Metric >= 0 & result$`_data`$Metric < 1))
})

test_that("Flag filtering works correctly", {
  reportingResults_filt <- gsm.core::reportingResults %>%
    dplyr::filter(MetricID == "Analysis_kri0001")
  result <- Report_MetricTable(reportingResults_filt, gsm.core::reportingGroups)
  expect_s3_class(result, "gt_tbl")
  expect_true(all(result$`_data`$Flag != 0))
})

test_that("Score rounding works correctly", {
  reportingResults_filt <- gsm.core::reportingResults %>%
    dplyr::filter(MetricID == "Analysis_kri0001")
  result <- Report_MetricTable(reportingResults_filt, gsm.core::reportingGroups)
  expect_true(any(grepl("0.05", result)))
})

test_that("Errors out when multiple MetricIDs passed in", {
  expect_error(Report_MetricTable(
    gsm.core::reportingResults,
    gsm.core::reportingGroups
  ))
})

test_that("Runs with just results with NULL group argument", {
  reportingResults_filt <- gsm.core::reportingResults %>%
    dplyr::filter(MetricID == "Analysis_kri0001")
  result <- Report_MetricTable(reportingResults_filt)
  expect_s3_class(result, "gt_tbl")
})

test_that("Output is expected object (#107)", {
  zero_flags <- c("0X003", "0X039")
  red_flags <- c("0X113", "0X025")
  amber_flags <- c("0X119", "0X046")

  reportingResults_filt <- gsm.core::reportingResults %>%
    FilterByLatestSnapshotDate() %>%
    dplyr::filter(
      MetricID == "Analysis_kri0001",
      GroupID %in% c(zero_flags, red_flags, amber_flags)
    ) %>%
    # Add an NA row back for representation.
    dplyr::bind_rows(
      tibble::tibble(
        GroupID = "0X000",
        GroupLevel = "Site",
        Numerator = 4L,
        Denominator = 8L,
        Metric = 0.5,
        Score = NA,
        Flag = NA,
        MetricID = "kri0001",
        SnapshotDate = as.Date("2012-12-31"),
        StudyID = "ABC-123"
      )
    )
  x <- Report_MetricTable(reportingResults_filt, gsm.core::reportingGroups)
  # Check structure
  expect_s3_class(x, "shiny.tag")
  expect_equal(x$name, "p")
  expect_true("output_label" %in% names(attributes(x)))
  expect_true(grepl("Metric Table", attr(x, "output_label")))
})
