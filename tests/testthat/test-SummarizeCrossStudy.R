# Helper function to create test data
create_test_results <- function() {
  # Create test results with Analysis_srs0001 (site risk scores)
  tibble::tibble(
    GroupID = rep(c("Site001", "Site002", "Site003"), each = 2),
    GroupLevel = "Site",
    StudyID = rep(c("Study1", "Study2"), 3),
    MetricID = "Analysis_srs0001",
    Score = c(1.5, 2.3, 0.8, 1.2, 3.1, 2.9),
    Numerator = c(10, 15, 5, 8, 20, 18),
    Denominator = c(100, 120, 80, 90, 150, 140),
    Metric = c(0.1, 0.125, 0.0625, 0.089, 0.133, 0.129),
    Flag = c(1, 2, 0, 1, 2, 2),
    SnapshotDate = as.Date("2025-01-01")
  )
}

create_test_groups <- function() {
  # Create test groups data with investigator names
  tibble::tibble(
    GroupID = rep(c("Site001", "Site002", "Site003"), each = 2),
    GroupLevel = "Site",
    StudyID = rep(c("Study1", "Study2"), 3),
    Param = "InvestigatorLastName",
    Value = c("Smith", "Smith", "Jones", "Jones", "Brown", "Williams")
  )
}

test_that("Returns correct structure with required columns (#71, #144)", {
  dfResults <- create_test_results()

  result <- SummarizeCrossStudy(dfResults)

  # Check return type
  expect_true(is.data.frame(result))

  # Check required columns exist
  expect_true(all(
    c("GroupID", "NumStudies", "AvgRiskScore", "MaxRiskScore") %in%
      names(result)
  ))

  # Check number of rows (should be 3 unique sites)
  expect_equal(nrow(result), 3)
})

test_that("Calculates metrics correctly for multiple studies (#71, #144)", {
  dfResults <- create_test_results()

  result <- SummarizeCrossStudy(dfResults)

  # Site001: 2 studies, avg = (1.5 + 2.3) / 2 = 1.9, max = 2.3
  site001 <- result[result$GroupID == "Site001", ]
  expect_equal(site001$NumStudies, 2)
  expect_equal(site001$AvgRiskScore, 1.9)
  expect_equal(site001$MaxRiskScore, 2.3)

  # Site002: 2 studies, avg = (0.8 + 1.2) / 2 = 1.0, max = 1.2
  site002 <- result[result$GroupID == "Site002", ]
  expect_equal(site002$NumStudies, 2)
  expect_equal(site002$AvgRiskScore, 1.0)
  expect_equal(site002$MaxRiskScore, 1.2)

  # Site003: 2 studies, avg = (3.1 + 2.9) / 2 = 3.0, max = 3.1
  site003 <- result[result$GroupID == "Site003", ]
  expect_equal(site003$NumStudies, 2)
  expect_equal(site003$AvgRiskScore, 3.0)
  expect_equal(site003$MaxRiskScore, 3.1)
})

test_that("Sorts by average risk score descending (#71, #144)", {
  dfResults <- create_test_results()

  result <- SummarizeCrossStudy(dfResults)

  # First row should be Site003 (highest avg: 3.0)
  expect_equal(result$GroupID[1], "Site003")

  # Last row should be Site002 (lowest avg: 1.0)
  expect_equal(result$GroupID[nrow(result)], "Site002")
})

test_that("Works with single study per site (#71, #144)", {
  dfResults <- tibble::tibble(
    GroupID = c("Site001", "Site002"),
    GroupLevel = "Site",
    StudyID = c("Study1", "Study1"),
    MetricID = "Analysis_srs0001",
    Score = c(1.5, 2.3),
    Numerator = c(10, 15),
    Denominator = c(100, 120),
    Metric = c(0.1, 0.125),
    Flag = c(1, 2),
    SnapshotDate = as.Date("2025-01-01")
  )

  result <- SummarizeCrossStudy(dfResults)

  expect_equal(nrow(result), 2)
  expect_equal(result$NumStudies[1], 1)
  expect_equal(result$AvgRiskScore[1], result$MaxRiskScore[1])
})

test_that("Adds InvestigatorName when dfGroups provided (#71, #144)", {
  dfResults <- create_test_results()
  dfGroups <- create_test_groups()

  # Suppress expected warning about Site003 having multiple names
  suppressWarnings({
    result <- SummarizeCrossStudy(dfResults, dfGroups = dfGroups)
  })

  # Check InvestigatorName column exists
  expect_true("InvestigatorName" %in% names(result))

  # Check investigator names are correct
  expect_equal(result$InvestigatorName[result$GroupID == "Site001"], "Smith")
  expect_equal(result$InvestigatorName[result$GroupID == "Site002"], "Jones")
})

test_that("Handles multiple investigator names per site (#71, #144)", {
  dfResults <- create_test_results()
  dfGroups <- create_test_groups()

  # Site003 has different names across studies (Brown, Williams)
  expect_warning(
    result <- SummarizeCrossStudy(dfResults, dfGroups = dfGroups),
    "multiple investigator names"
  )

  # Check that Site003 gets "Multiple" as InvestigatorName
  expect_equal(
    result$InvestigatorName[result$GroupID == "Site003"],
    "Multiple"
  )
})

test_that("Handles missing columns in dfGroups gracefully (#71, #144)", {
  dfResults <- create_test_results()
  dfGroups_incomplete <- tibble::tibble(
    GroupID = c("Site001", "Site002"),
    Value = c("Smith", "Jones")
    # Missing StudyID and Param columns
  )

  expect_warning(
    result <- SummarizeCrossStudy(
      dfResults,
      dfGroups = dfGroups_incomplete
    ),
    "missing required columns"
  )

  # Should still return result without InvestigatorName
  expect_false("InvestigatorName" %in% names(result))
})

test_that("Respects strGroupLevel parameter (#71, #144)", {
  dfResults <- create_test_results() %>%
    dplyr::bind_rows(
      tibble::tibble(
        GroupID = c("Country001"),
        GroupLevel = "Country",
        StudyID = c("Study1"),
        MetricID = "Analysis_srs0001",
        Score = c(2.0),
        Numerator = c(50),
        Denominator = c(500),
        Metric = c(0.1),
        Flag = c(1),
        SnapshotDate = as.Date("2025-01-01")
      )
    )

  result_site <- SummarizeCrossStudy(dfResults, strGroupLevel = "Site")
  result_country <- SummarizeCrossStudy(dfResults, strGroupLevel = "Country")

  # Site level should have 3 rows
  expect_equal(nrow(result_site), 3)

  # Country level should have 1 row
  expect_equal(nrow(result_country), 1)
  expect_equal(result_country$GroupID[1], "Country001")
})

test_that("Errors when no data for specified GroupLevel (#71, #144)", {
  dfResults <- create_test_results()

  expect_error(
    SummarizeCrossStudy(dfResults, strGroupLevel = "Country"),
    "No data found for GroupLevel: Country"
  )
})

test_that("Returns empty data frame when Analysis_srs0001 not present (#71, #144)", {
  dfResults <- create_test_results() %>%
    dplyr::mutate(MetricID = "kri0001") # Change to different metric

  # Function should return empty summary since no Analysis_srs0001 data
  # (Warning from dplyr::max on empty data is expected)
  suppressWarnings({
    result <- SummarizeCrossStudy(dfResults)
  })
  expect_equal(nrow(result), 0)
})

test_that("Validates input types (#71, #144)", {
  dfResults <- create_test_results()

  # dfResults must be a data.frame
  expect_error(
    SummarizeCrossStudy(list()),
    "is.data.frame\\(dfResults\\) is not TRUE"
  )

  # strGroupLevel must be character
  expect_error(
    SummarizeCrossStudy(dfResults, strGroupLevel = 123),
    "is.character\\(strGroupLevel\\)"
  )

  # dfGroups must be data.frame or NULL
  expect_error(
    SummarizeCrossStudy(dfResults, dfGroups = "not a dataframe"),
    "is.null\\(dfGroups\\) \\|\\| is.data.frame\\(dfGroups\\) is not TRUE"
  )
})

test_that("Adds TotalEnrollment summed across studies when dfGroups provided (#256)", {
  dfResults <- create_test_results()
  dfGroups <- tibble::tibble(
    GroupID = rep(c("Site001", "Site002", "Site003"), each = 2),
    GroupLevel = "Site",
    StudyID = rep(c("Study1", "Study2"), 3),
    Param = "ParticipantCount",
    Value = c("10", "15", "20", "20", "5", "5")
  )

  result <- SummarizeCrossStudy(dfResults, dfGroups = dfGroups)

  expect_true("TotalEnrollment" %in% names(result))
  expect_equal(result$TotalEnrollment[result$GroupID == "Site001"], 25)
  expect_equal(result$TotalEnrollment[result$GroupID == "Site002"], 40)
  expect_equal(result$TotalEnrollment[result$GroupID == "Site003"], 10)
})

test_that("Only sums ParticipantCount at the requested GroupLevel (#256)", {
  dfResults <- create_test_results()
  dfGroups <- tibble::tibble(
    GroupID = c("Site001", "Site001", "Study1"),
    GroupLevel = c("Site", "Site", "Study"),
    StudyID = c("Study1", "Study2", "Study1"),
    Param = "ParticipantCount",
    # Study-level total (900) should not be mixed into the Site001 sum
    Value = c("10", "15", "900")
  )

  result <- SummarizeCrossStudy(dfResults, dfGroups = dfGroups)

  expect_equal(result$TotalEnrollment[result$GroupID == "Site001"], 25)
})

test_that("TotalEnrollment is NA when ParticipantCount is absent from dfGroups (#256)", {
  dfResults <- create_test_results()
  dfGroups <- create_test_groups() # only has InvestigatorLastName

  # Suppress expected warning about Site003 having multiple names
  suppressWarnings({
    result <- SummarizeCrossStudy(dfResults, dfGroups = dfGroups)
  })

  expect_true("TotalEnrollment" %in% names(result))
  expect_true(all(is.na(result$TotalEnrollment)))
})

test_that("Works with custom strNameCol parameter (#71, #144)", {
  dfResults <- create_test_results()
  dfGroups <- tibble::tibble(
    GroupID = rep(c("Site001", "Site002"), each = 2),
    GroupLevel = "Site",
    StudyID = rep(c("Study1", "Study2"), 2),
    Param = "InvestigatorFirstName", # Different param name
    Value = c("John", "John", "Jane", "Jane")
  )

  result <- SummarizeCrossStudy(
    dfResults,
    dfGroups = dfGroups,
    strNameCol = "InvestigatorFirstName"
  )

  expect_true("InvestigatorName" %in% names(result))
  expect_equal(result$InvestigatorName[result$GroupID == "Site001"], "John")
  expect_equal(result$InvestigatorName[result$GroupID == "Site002"], "Jane")
})
