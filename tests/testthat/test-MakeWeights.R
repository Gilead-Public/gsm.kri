# Test data setup helpers ----

create_sample_metrics <- function() {
  data.frame(
    MetricID = c(
      "Analysis_kri0001",
      "Analysis_kri0002",
      "Analysis_kri0003",
      "Analysis_kri0004"
    ),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2", "-1,0,1", "-2,-1,0,1,2"),
    RiskScoreWeight = c("4,2,0,2,4", "8,4,0,4,8", "2,0,2", "16,8,0,8,16"),
    stringsAsFactors = FALSE
  )
}

create_minimal_metrics <- function() {
  data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "0,1",
    RiskScoreWeight = "0,4",
    stringsAsFactors = FALSE
  )
}

# Basic functionality tests ----

test_that("MakeWeights returns correct structure (#135)", {
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Check return structure
  expect_s3_class(dfWeights, "data.frame")
  expect_named(dfWeights, c("MetricID", "Flag", "Weight", "WeightMax"))

  # Check that all values are numeric except MetricID
  expect_type(dfWeights$Flag, "double")
  expect_type(dfWeights$Weight, "double")
  expect_type(dfWeights$WeightMax, "double")
  expect_type(dfWeights$MetricID, "character")
})

test_that("MakeWeights parses comma-separated values correctly (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0,1,2",
    RiskScoreWeight = "4,2,0,2,4",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  # Should have 5 rows (one for each flag value)
  expect_equal(nrow(dfWeights), 5)

  # Check flag values
  expect_equal(sort(dfWeights$Flag), c(-2, -1, 0, 1, 2))

  # Check weight values
  expect_equal(dfWeights$Weight[dfWeights$Flag == -2], 4)
  expect_equal(dfWeights$Weight[dfWeights$Flag == -1], 2)
  expect_equal(dfWeights$Weight[dfWeights$Flag == 0], 0)
  expect_equal(dfWeights$Weight[dfWeights$Flag == 1], 2)
  expect_equal(dfWeights$Weight[dfWeights$Flag == 2], 4)
})

test_that("MakeWeights calculates WeightMax correctly (#135)", {
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Check WeightMax for each MetricID
  kri0001_weights <- dfWeights[dfWeights$MetricID == "Analysis_kri0001", ]
  expect_true(all(kri0001_weights$WeightMax == 4)) # max(4,2,0,2,4) = 4

  kri0002_weights <- dfWeights[dfWeights$MetricID == "Analysis_kri0002", ]
  expect_true(all(kri0002_weights$WeightMax == 8)) # max(8,4,0,4,8) = 8

  kri0003_weights <- dfWeights[dfWeights$MetricID == "Analysis_kri0003", ]
  expect_true(all(kri0003_weights$WeightMax == 2)) # max(2,0,2) = 2

  kri0004_weights <- dfWeights[dfWeights$MetricID == "Analysis_kri0004", ]
  expect_true(all(kri0004_weights$WeightMax == 16)) # max(16,8,0,8,16) = 16
})

test_that("MakeWeights handles multiple metrics (#135)", {
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Check that all MetricIDs are present
  expect_true(all(unique(dfMetrics$MetricID) %in% dfWeights$MetricID))

  # Total rows should be sum of all flag-weight pairs
  # kri0001: 5, kri0002: 5, kri0003: 3, kri0004: 5 = 18 total
  expect_equal(nrow(dfWeights), 18)
})

# Input validation tests ----

test_that("MakeWeights validates required columns (#135)", {
  dfMetrics <- create_sample_metrics()

  # Test missing MetricID
  expect_error(
    MakeWeights(dfMetrics[, !names(dfMetrics) %in% "MetricID"]),
    "Missing required columns in dfMetrics: MetricID"
  )

  # Test missing Flag
  expect_error(
    MakeWeights(dfMetrics[, !names(dfMetrics) %in% "Flag"]),
    "Missing required columns in dfMetrics: Flag"
  )

  # Test missing RiskScoreWeight
  expect_error(
    MakeWeights(dfMetrics[, !names(dfMetrics) %in% "RiskScoreWeight"]),
    "Missing required columns in dfMetrics: RiskScoreWeight"
  )

  # Test missing multiple columns
  expect_error(
    MakeWeights(dfMetrics[, "MetricID", drop = FALSE]),
    "Missing required columns in dfMetrics:"
  )
})

# NA handling tests ----

test_that("MakeWeights filters out NA values (#135)", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
    Flag = c("-1,0,1", NA, "-1,0,1"),
    RiskScoreWeight = c("2,0,2", "4,0,4", NA),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  # Should only have rows from kri0001 (kri0002 and kri0003 have NAs)
  expect_equal(nrow(dfWeights), 3) # Only 3 rows from kri0001
  expect_equal(unique(dfWeights$MetricID), "Analysis_kri0001")
})

test_that("MakeWeights handles empty data after filtering NAs (#135)", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c(NA, NA),
    RiskScoreWeight = c(NA, NA),
    stringsAsFactors = FALSE
  )

  expect_warning(
    dfWeights <- MakeWeights(dfMetrics),
    "No valid rows found in dfMetrics with non-NA Flag and RiskScoreWeight values."
  )

  # Should return empty data frame with correct columns
  expect_equal(nrow(dfWeights), 0)
  expect_named(dfWeights, c("MetricID", "Flag", "Weight", "WeightMax"))
})

# Edge cases ----

test_that("MakeWeights handles single flag-weight pair (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "1",
    RiskScoreWeight = "5",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_equal(nrow(dfWeights), 1)
  expect_equal(dfWeights$Flag, 1)
  expect_equal(dfWeights$Weight, 5)
  expect_equal(dfWeights$WeightMax, 5)
})

test_that("MakeWeights handles zero weights (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-1,0,1",
    RiskScoreWeight = "0,0,0",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_equal(nrow(dfWeights), 3)
  expect_true(all(dfWeights$Weight == 0))
  expect_true(all(dfWeights$WeightMax == 0))
})

test_that("MakeWeights handles negative flags (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0",
    RiskScoreWeight = "8,4,0",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_equal(sort(dfWeights$Flag), c(-2, -1, 0))
  expect_equal(dfWeights$Weight[dfWeights$Flag == -2], 8)
  expect_equal(dfWeights$Weight[dfWeights$Flag == -1], 4)
})

test_that("MakeWeights handles large numbers (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "0,1",
    RiskScoreWeight = "0,999999",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_equal(dfWeights$Weight[dfWeights$Flag == 1], 999999)
  expect_equal(dfWeights$WeightMax, c(999999, 999999))
})

test_that("MakeWeights handles decimal weights (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "0,1,2",
    RiskScoreWeight = "0,2.5,5.75",
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_equal(dfWeights$Weight[dfWeights$Flag == 1], 2.5)
  expect_equal(dfWeights$Weight[dfWeights$Flag == 2], 5.75)
  expect_true(all(dfWeights$WeightMax == 5.75))
})

# Integration tests ----

test_that("MakeWeights output can be joined to results data (#135)", {
  dfMetrics <- create_sample_metrics()
  dfWeights <- MakeWeights(dfMetrics)

  # Create sample results data
  dfResults <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0002"),
    Flag = c(-1, 1, 2),
    GroupID = c("Site001", "Site002", "Site003"),
    stringsAsFactors = FALSE
  )

  # Join weights to results
  dfJoined <- dfResults %>%
    left_join(dfWeights, by = c("MetricID", "Flag"))

  # Check that weights were joined correctly
  expect_equal(nrow(dfJoined), 3)
  expect_true(all(c("Weight", "WeightMax") %in% names(dfJoined)))
  expect_equal(dfJoined$Weight[dfJoined$Flag == -1], 2) # From kri0001
  expect_equal(dfJoined$Weight[dfJoined$Flag == 1], 2) # From kri0001
  expect_equal(
    dfJoined$Weight[
      dfJoined$Flag == 2 & dfJoined$MetricID == "Analysis_kri0002"
    ],
    8
  )
})

test_that("MakeWeights works with gsm.core::reportingMetrics (#135)", {
  skip_if_not_installed("gsm.core")

  # Test with actual gsm.core data
  dfWeights <- MakeWeights(gsm.core::reportingMetrics)

  # Check basic structure
  expect_s3_class(dfWeights, "data.frame")
  expect_named(dfWeights, c("MetricID", "Flag", "Weight", "WeightMax"))

  # Check that we have data
  expect_gt(nrow(dfWeights), 0)

  # Check that all weights are numeric
  expect_true(all(!is.na(dfWeights$Weight)))
  expect_true(all(!is.na(dfWeights$WeightMax)))
})

# Symmetric weights tests ----

test_that("MakeWeights handles symmetric weights correctly (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0,1,2",
    RiskScoreWeight = "8,4,0,4,8", # Symmetric weights
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  # Check symmetry
  expect_equal(
    dfWeights$Weight[dfWeights$Flag == -2],
    dfWeights$Weight[dfWeights$Flag == 2]
  )
  expect_equal(
    dfWeights$Weight[dfWeights$Flag == -1],
    dfWeights$Weight[dfWeights$Flag == 1]
  )
})

test_that("MakeWeights handles asymmetric weights correctly (#135)", {
  dfMetrics <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0,1,2",
    RiskScoreWeight = "16,8,0,4,2", # Asymmetric weights
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  # Check that weights are different
  expect_false(
    dfWeights$Weight[dfWeights$Flag == -2] ==
      dfWeights$Weight[dfWeights$Flag == 2]
  )
  expect_equal(dfWeights$Weight[dfWeights$Flag == -2], 16)
  expect_equal(dfWeights$Weight[dfWeights$Flag == 2], 2)
  expect_equal(dfWeights$WeightMax, rep(16, 5)) # Max is 16
})

# Length validation tests ----

test_that("MakeWeights detects mismatched Flag and RiskScoreWeight lengths (#135)", {
  # Test case: More flags than weights
  dfMetrics_mismatch1 <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "-2,-1,0,1,2", # 5 flags
    RiskScoreWeight = "4,2,0,2", # 4 weights - mismatch!
    stringsAsFactors = FALSE
  )

  expect_error(
    MakeWeights(dfMetrics_mismatch1),
    "Flag and RiskScoreWeight lists must have the same length"
  )
  expect_error(
    MakeWeights(dfMetrics_mismatch1),
    "Analysis_kri0001: 5 flags vs 4 weights"
  )
})

test_that("MakeWeights detects mismatched lengths with multiple metrics (#135)", {
  # Test case: Multiple metrics with mismatches
  dfMetrics_mismatch2 <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c("-2,-1,0", "0,1,2"), # 3 flags each
    RiskScoreWeight = c("4,2", "0,2,4,8"), # 2 weights, 4 weights - both mismatch!
    stringsAsFactors = FALSE
  )

  expect_error(
    MakeWeights(dfMetrics_mismatch2),
    "Flag and RiskScoreWeight lists must have the same length"
  )
  expect_error(
    MakeWeights(dfMetrics_mismatch2),
    "Analysis_kri0001: 3 flags vs 2 weights"
  )
  expect_error(
    MakeWeights(dfMetrics_mismatch2),
    "Analysis_kri0002: 3 flags vs 4 weights"
  )
})

test_that("MakeWeights detects fewer weights than flags (#135)", {
  dfMetrics_mismatch3 <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "0,1,2", # 3 flags
    RiskScoreWeight = "0,4", # 2 weights
    stringsAsFactors = FALSE
  )

  expect_error(
    MakeWeights(dfMetrics_mismatch3),
    "3 flags vs 2 weights"
  )
})

test_that("MakeWeights detects more weights than flags (#135)", {
  dfMetrics_mismatch4 <- data.frame(
    MetricID = "Analysis_kri0001",
    Flag = "0,1", # 2 flags
    RiskScoreWeight = "0,2,4", # 3 weights
    stringsAsFactors = FALSE
  )

  expect_error(
    MakeWeights(dfMetrics_mismatch4),
    "2 flags vs 3 weights"
  )
})

test_that("MakeWeights succeeds when all lengths match (#135)", {
  # Test case: All metrics have matching lengths
  dfMetrics_match <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
    Flag = c("-2,-1,0,1,2", "0,1", "-1,0,1"),
    RiskScoreWeight = c("4,2,0,2,4", "0,4", "2,0,2"),
    stringsAsFactors = FALSE
  )

  # Should not throw an error
  expect_silent(dfWeights <- MakeWeights(dfMetrics_match))
})

# Active column filtering tests ----

test_that("MakeWeights excludes inactive metrics from weight table (#226)", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_kri0003"),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2", "-2,-1,0,1,2"),
    RiskScoreWeight = c("4,2,0,2,4", "4,2,0,2,4", "4,2,0,2,4"),
    Active = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_false("Analysis_kri0002" %in% dfWeights$MetricID)
  expect_true("Analysis_kri0001" %in% dfWeights$MetricID)
  expect_true("Analysis_kri0003" %in% dfWeights$MetricID)
})

test_that("MakeWeights includes all metrics when Active column is absent (#226)", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2"),
    RiskScoreWeight = c("4,2,0,2,4", "4,2,0,2,4"),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_true("Analysis_kri0001" %in% dfWeights$MetricID)
  expect_true("Analysis_kri0002" %in% dfWeights$MetricID)
})

test_that("MakeWeights includes metrics with NA Active (#226)", {
  dfMetrics <- data.frame(
    MetricID = c("Analysis_kri0001", "Analysis_kri0002"),
    Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2"),
    RiskScoreWeight = c("4,2,0,2,4", "4,2,0,2,4"),
    Active = c(TRUE, NA),
    stringsAsFactors = FALSE
  )

  dfWeights <- MakeWeights(dfMetrics)

  expect_true("Analysis_kri0001" %in% dfWeights$MetricID)
  expect_true("Analysis_kri0002" %in% dfWeights$MetricID)
})
