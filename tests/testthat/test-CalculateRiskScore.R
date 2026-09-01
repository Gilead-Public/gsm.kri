# Test data setup helpers ----

create_sample_metrics <- function() {
  data.frame(
    MetricID = c(
      "Analysis_kri0001",
      "Analysis_kri0002",
      "Analysis_kri0003",
      "Analysis_kri0004"
    ),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2", "-2,-1,0,1,2", "-2,-1,0,1,2"),
    RiskScoreWeight = c("4,2,0,2,4", "4,2,0,2,4", "4,2,0,2,4", "16,8,0,8,16"),
    stringsAsFactors = FALSE
  )
}

create_sample_results <- function() {
  data.frame(
    GroupLevel = rep("Site", 12),
    GroupID = rep(c("Site001", "Site002", "Site003"), 4),
    MetricID = rep(
      c(
        "Analysis_kri0001",
        "Analysis_kri0002",
        "Analysis_kri0003",
        "Analysis_kri0004"
      ),
      3
    ),
    Flag = c(1, -1, 0, 2, -1, 1, 0, -2, 0, -1, 1, -2),
    Numerator = c(10, 5, 8, 3, 15, 12, 6, 2, 20, 18, 14, 1),
    Denominator = c(100, 100, 100, 100, 150, 150, 150, 150, 200, 200, 200, 200),
    Metric = c(
      0.1,
      0.05,
      0.08,
      0.03,
      0.1,
      0.08,
      0.04,
      0.013,
      0.1,
      0.09,
      0.07,
      0.005
    ),
    SnapshotDate = as.Date("2025-01-01"),
    StudyID = "STUDY001",
    stringsAsFactors = FALSE
  )
}

create_minimal_results <- function() {
  data.frame(
    GroupLevel = "Site",
    GroupID = "Site001",
    MetricID = "Analysis_kri0001",
    Flag = 1,
    stringsAsFactors = FALSE
  )
}

# Basic functionality tests ----

test_that("CalculateRiskScore returns correct structure (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  # Check return structure
  expect_s3_class(dfRiskScore, "data.frame")
  expect_named(
    dfRiskScore,
    c(
      "GroupLevel",
      "GroupID",
      "MetricID",
      "Numerator",
      "Denominator",
      "Metric",
      "Score",
      "Flag"
    )
  )

  # Check default MetricID
  expect_true(all(dfRiskScore$MetricID == "Analysis_srs0001"))

  # Check number of rows equals unique groups
  expected_groups <- distinct(dfResults, GroupLevel, GroupID)
  expect_equal(nrow(dfRiskScore), nrow(expected_groups))
})

test_that("CalculateRiskScore calculates risk scores correctly (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  # Calculate expected values manually
  # Global denominator = sum of max weights = 4 + 4 + 4 + 16 = 28
  expected_global_denom <- 28

  # For Site001: Flags are 1, -1, 0, 2 for metrics kri0001-kri0004
  # Weights: 2 (flag 1), 2 (flag -1), 0 (flag 0), 16 (flag 2) = 20
  site001_row <- dfRiskScore[dfRiskScore$GroupID == "Site001", ]
  expect_equal(site001_row$Numerator, 20)
  expect_equal(site001_row$Denominator, expected_global_denom)
  expect_equal(
    site001_row$Metric,
    site001_row$Numerator / site001_row$Denominator * 100
  )
  expect_equal(site001_row$Score, site001_row$Metric)
  expect_true(is.na(site001_row$Flag))
})

test_that("CalculateRiskScore handles custom MetricID (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)
  custom_metric_id <- "Analysis_custom_risk"
  dfRiskScore <- CalculateRiskScore(
    dfResults,
    dfWeights,
    strMetricID = custom_metric_id
  )

  expect_true(all(dfRiskScore$MetricID == custom_metric_id))
})

# Input validation tests ----

test_that("CalculateRiskScore validates required columns in dfResults (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Test missing required columns
  required_cols <- c("GroupLevel", "GroupID", "MetricID", "Flag")
  for (col in required_cols) {
    dfResults_missing <- dfResults[, !names(dfResults) %in% col]
    expect_error(
      CalculateRiskScore(dfResults_missing, dfWeights),
      paste("Missing required columns in dfResults:", col)
    )
  }
})

test_that("CalculateRiskScore validates required columns in dfWeights (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Test missing required columns in dfWeights
  required_cols <- c("MetricID", "Flag", "Weight", "WeightMax")
  for (col in required_cols) {
    dfWeights_missing <- dfWeights[, !names(dfWeights) %in% col]
    expect_error(
      CalculateRiskScore(dfResults, dfWeights_missing),
      paste("Missing required columns in dfWeights:", col)
    )
  }
})

test_that("CalculateRiskScore validates MetricID uniqueness (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Add existing MetricID to test data - need to match all columns
  dfResults_with_existing <- rbind(
    dfResults,
    data.frame(
      GroupLevel = "Site",
      GroupID = "Site004",
      MetricID = "Analysis_srs0001", # This should cause an error
      Flag = 0,
      Numerator = 10,
      Denominator = 100,
      Metric = 0.1,
      SnapshotDate = as.Date("2025-01-01"),
      StudyID = "STUDY001",
      stringsAsFactors = FALSE
    )
  )

  expect_error(
    CalculateRiskScore(dfResults_with_existing, dfWeights),
    "MetricID Analysis_srs0001 already exists in dfResults"
  )
})

test_that("CalculateRiskScore validates numeric Weight and WeightMax (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Test non-numeric Weight
  dfWeights_char_weight <- dfWeights
  dfWeights_char_weight$Weight <- as.character(dfWeights_char_weight$Weight)
  expect_error(
    CalculateRiskScore(dfResults, dfWeights_char_weight),
    "Columns 'Weight' and 'WeightMax' must be numeric"
  )

  # Test non-numeric WeightMax
  dfWeights_char_weightmax <- dfWeights
  dfWeights_char_weightmax$WeightMax <- as.character(
    dfWeights_char_weightmax$WeightMax
  )
  expect_error(
    CalculateRiskScore(dfResults, dfWeights_char_weightmax),
    "Columns 'Weight' and 'WeightMax' must be numeric"
  )
})

test_that("CalculateRiskScore validates unique combinations (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Create duplicate combination
  dfResults_duplicate <- rbind(dfResults, dfResults[1, ])
  expect_error(
    CalculateRiskScore(dfResults_duplicate, dfWeights),
    "The combination of 'GroupLevel', 'GroupID', and 'MetricID' must be unique"
  )
})

test_that("CalculateRiskScore validates consistent WeightMax per MetricID (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Create inconsistent WeightMax for same MetricID
  dfWeights$WeightMax[dfWeights$MetricID == "Analysis_kri0001"] <- c(
    4,
    4,
    4,
    8,
    4
  ) # Mixed values
  expect_error(
    CalculateRiskScore(dfResults, dfWeights),
    "'WeightMax' should be the same for each 'MetricID'"
  )
})

# NA handling tests ----

test_that("CalculateRiskScore handles NA values with warning (#127)", {
  dfResults <- data.frame(
    GroupLevel = rep("Site", 4),
    GroupID = rep(c("Site001", "Site002"), each = 2),
    MetricID = rep(c("Analysis_kri0001", "Analysis_kri0002"), 2),
    Flag = c(1, -1, 1, -1),
    stringsAsFactors = FALSE
  )

  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c("1,-1", "1"), # kri0002 missing flag -1, will create NA after join
    RiskScoreWeight = c("4,2", "4"),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_warning(
    dfRiskScore <- CalculateRiskScore(dfResults, dfWeights),
    "Rows with NA values in 'Weight' or 'WeightMax' have been dropped"
  )

  # Check that rows were calculated
  expect_equal(nrow(dfRiskScore), 2)
})

test_that("CalculateRiskScore works with all NA weights for a group (#127)", {
  dfResults <- data.frame(
    GroupLevel = rep("Site", 4),
    GroupID = rep(c("Site001", "Site002"), each = 2),
    MetricID = rep(c("Analysis_kri0001", "Analysis_kri0002"), 2),
    Flag = c(1, 0, 0, 1), # Site001 has valid weight for kri0001, Site002 has valid weight for kri0002
    stringsAsFactors = FALSE
  )

  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c("0,1", "0,1"),
    RiskScoreWeight = c("0,4", "0,8"),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  # Both sites should still appear
  expect_equal(nrow(dfRiskScore), 2)
  expect_equal(dfRiskScore$Numerator[dfRiskScore$GroupID == "Site001"], 4)
  expect_equal(dfRiskScore$Numerator[dfRiskScore$GroupID == "Site002"], 8)
})

# Edge cases ----

test_that("CalculateRiskScore handles single row input (#127)", {
  dfResults <- create_minimal_results()
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "1",
    RiskScoreWeight = "4",
    stringsAsFactors = FALSE
  )
  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  expect_equal(nrow(dfRiskScore), 1)
  expect_equal(dfRiskScore$GroupID, "Site001")
  expect_equal(dfRiskScore$Numerator, 4)
  expect_equal(dfRiskScore$Denominator, 4) # Only one MetricID with WeightMax = 4
  expect_equal(dfRiskScore$Metric, 100) # (4/4) * 100
})

test_that("CalculateRiskScore handles zero weights (#127)", {
  dfResults <- create_sample_results()
  dfMetrics <- data.frame(
    MetricID = unique(dfResults$MetricID),
    Flag = rep("-2,-1,0,1,2", 4), # Include all flags that appear in results
    RiskScoreWeight = rep("0,0,0,0,0", 4), # All weights are zero
    stringsAsFactors = FALSE
  )
  dfWeights <- MakeWeights(dfMetrics)

  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  # All numerators should be 0
  expect_true(all(dfRiskScore$Numerator == 0))
  # Denominator will be 0, so Metric will be NaN (0/0)
  expect_true(all(dfRiskScore$Denominator == 0))
  expect_true(all(is.nan(dfRiskScore$Metric)))
})

test_that("CalculateRiskScore handles large numbers (#127)", {
  dfResults <- create_minimal_results()
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "1",
    RiskScoreWeight = "999999",
    stringsAsFactors = FALSE
  )
  dfWeights <- MakeWeights(dfMetrics)

  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  expect_equal(dfRiskScore$Numerator, 999999)
  expect_equal(dfRiskScore$Denominator, 999999)
  expect_equal(dfRiskScore$Metric, 100)
})

# Group aggregation tests ----

test_that("CalculateRiskScore aggregates weights correctly across metrics (#127)", {
  dfResults <- data.frame(
    GroupLevel = rep("Site", 6),
    GroupID = rep(c("Site001", "Site002"), each = 3),
    MetricID = rep(
      c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
      2
    ),
    Flag = c(1, -1, 2, 0, 1, -2),
    stringsAsFactors = FALSE
  )

  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2", "-2,-1,0,1,2"),
    RiskScoreWeight = c("8,4,0,4,8", "4,2,0,2,4", "16,8,0,8,16"),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  site001_score <- dfRiskScore[dfRiskScore$GroupID == "Site001", ]
  site002_score <- dfRiskScore[dfRiskScore$GroupID == "Site002", ]

  # Site001: flag 1 in kri0001 (4) + flag -1 in kri0002 (2) + flag 2 in kri0003 (16) = 22
  expect_equal(site001_score$Numerator, 22)
  # Site002: flag 0 in kri0001 (0) + flag 1 in kri0002 (2) + flag -2 in kri0003 (16) = 18
  expect_equal(site002_score$Numerator, 18)

  # Global denominator should be 8 + 4 + 16 = 28 (max weights for each unique MetricID)
  expect_equal(site001_score$Denominator, 28)
  expect_equal(site002_score$Denominator, 28)
})

test_that("CalculateRiskScore handles multiple group levels (#127)", {
  dfResults <- data.frame(
    GroupLevel = c("Site", "Country", "Site", "Country"),
    GroupID = c("Site001", "USA", "Site002", "Canada"),
    MetricID = rep("Analysis_kri0001", 4),
    Flag = c(1, 2, -1, 1),
    stringsAsFactors = FALSE
  )

  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0,1,2",
    RiskScoreWeight = "8,4,0,4,8",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)
  dfRiskScore <- CalculateRiskScore(dfResults, dfWeights)

  expect_equal(nrow(dfRiskScore), 4) # All four groups should be present
  expect_true("Site001" %in% dfRiskScore$GroupID)
  expect_true("USA" %in% dfRiskScore$GroupID)
  expect_true("Site002" %in% dfRiskScore$GroupID)
  expect_true("Canada" %in% dfRiskScore$GroupID)
})

# Active metric filtering tests ----

test_that("CalculateRiskScore excludes inactive metrics from denominator (#226)", {
  # Only active metrics appear in dfResults (inactive ones are never run)
  dfResults <- data.frame(
    GroupLevel = rep("Site", 4),
    GroupID = rep(c("Site001", "Site002"), each = 2),
    MetricID = rep(c("Analysis_kri0001", "Analysis_kri0002"), 2),
    Flag = c(1, 2, 0, -1),
    stringsAsFactors = FALSE
  )
  # kri0003 is inactive; its WeightMax (16) should NOT inflate the denominator
  dfMetrics_with_inactive <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
    Flag = rep("-2,-1,0,1,2", 3),
    RiskScoreWeight = c("4,2,0,2,4", "8,4,0,4,8", "16,8,0,8,16"),
    Active = c(TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  dfMetrics_active_only <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = rep("-2,-1,0,1,2", 2),
    RiskScoreWeight = c("4,2,0,2,4", "8,4,0,4,8"),
    stringsAsFactors = FALSE
  )

  dfWeights_with_inactive <- MakeWeights(dfMetrics_with_inactive)
  dfWeights_active_only <- MakeWeights(dfMetrics_active_only)

  # Both should produce the same results because kri0003 is filtered out
  dfRiskScore_inactive <- CalculateRiskScore(dfResults, dfWeights_with_inactive)
  dfRiskScore_active <- CalculateRiskScore(dfResults, dfWeights_active_only)

  # Denominator = 4 + 8 = 12 (active metrics only)
  expect_equal(unique(dfRiskScore_inactive$Denominator), 12)
  expect_equal(dfRiskScore_inactive$Denominator, dfRiskScore_active$Denominator)
  expect_equal(dfRiskScore_inactive$Numerator, dfRiskScore_active$Numerator)
})
