test_that("metric metadata reads the kri0020 and cou0020 rows with one warning format", {
  dfMetrics <- data.frame(
    ID = c("kri0020a", "cou0020b", "kri0001"),
    WindowLength = c(3, NA, 9),
    Threshold = c("0.2,0.3", "0.2,0.3", "1,2"),
    AccrualThreshold = c(NA, 4, 30)
  )
  expect_equal(rep_MetricMeta(dfMetrics, "WindowLength"), 3)
  expect_equal(rep_MetricMeta(dfMetrics, "Threshold"), "0.2,0.3")
  expect_equal(rep_MetricMeta(dfMetrics, "AccrualThreshold"), 4)
  expect_null(rep_MetricMeta(dfMetrics, "Flag"))
  expect_null(rep_MetricMeta(NULL, "WindowLength"))
  expect_null(rep_MetricMeta(dfMetrics[3, ], "WindowLength"))

  dfMetrics$AccrualThreshold <- c(5, 4, 30)
  expect_warning(
    expect_equal(rep_MetricMeta(dfMetrics, "AccrualThreshold"), 5),
    "kri0020/cou0020 metrics use different AccrualThreshold values"
  )
  dfMetrics$WindowLength <- c(3, 4, 9)
  expect_warning(rep_WindowLength(dfMetrics), "different WindowLength values")
  dfMetrics$Threshold <- c("0.2,0.3", "0.1,0.3", "1,2")
  expect_warning(rep_FlagThresholds("rate", dfMetrics = dfMetrics), "different Threshold values")
})

test_that("country-only metrics supply the report settings", {
  dfMetrics <- data.frame(
    ID = "cou0020a", WindowLength = 2, Threshold = "0.1,0.4", AccrualThreshold = 5
  )
  expect_equal(rep_WindowLength(dfMetrics)$window_length, 2)
  expect_equal(rep_FlagThresholds("rate", dfMetrics = dfMetrics), c(0.1, 0.4))
  expect_equal(rep_SiteRule(dfMetrics), list(thresholds = c(0.1, 0.4), accrual = 5))
})

test_that("flag severity orders Red, Amber, Green, Not evaluable", {
  expect_identical(
    rep_FlagSeverity(factor(c("Green", "Not evaluable", "Red", "Amber"))),
    c(1L, 0L, 3L, 2L)
  )
})

test_that("rep_FormatValue() drops trailing zeros without scientific notation", {
  expect_equal(rep_FormatValue(c(72, 72.50, 0.000012, 1234567)), c("72", "72.5", "0.000012", "1234567"))
})

test_that("only kri0020a-f and cou0020a-f metric IDs supply the settings", {
  dfMetrics <- data.frame(
    ID = c("kri0021", "xkri0020a", "kri00201", "kri0020g", "kri0020a"),
    WindowLength = c(9, 8, 7, 6, 3),
    Threshold = c("1,2", "1,2", "1,2", "1,2", "0.25,0.4")
  )
  expect_no_warning(expect_equal(rep_MetricMeta(dfMetrics, "WindowLength"), 3))
  expect_equal(rep_FlagThresholds("rate", dfMetrics = dfMetrics), c(0.25, 0.4))
  expect_null(rep_MetricMeta(dfMetrics[1:4, ], "WindowLength"))
})

test_that("a bad kri0020 metric Threshold names the metric Threshold, not vFlagThresholds", {
  for (strThreshold in c("0.2", "0.1,0.2,0.3", "0,0.3", "0.3,0.2", "a,b")) {
    dfMetrics <- data.frame(ID = "kri0020a", Threshold = strThreshold)
    expect_error(
      rep_FlagThresholds("rate", dfMetrics = dfMetrics),
      paste0("kri0020/cou0020 metric Threshold (\"", strThreshold, "\") must be two positive numbers"),
      fixed = TRUE
    )
  }
  # The argument wins over a bad metric Threshold.
  expect_equal(rep_FlagThresholds("rate", c(0.1, 0.2), data.frame(ID = "kri0020a", Threshold = "0.2")), c(0.1, 0.2))
})

test_that("thresholds must be above 0 under either rule", {
  for (strRule in c("count", "rate")) {
    expect_error(rep_FlagThresholds(strRule, c(0, 0)), "vFlagThresholds must be two positive numbers")
    expect_error(rep_FlagThresholds(strRule, c(0, 1)), "vFlagThresholds must be two positive numbers")
    expect_equal(rep_FlagThresholds(strRule, c(0.5, 0.5)), c(0.5, 0.5))
  }
})

test_that("rep_FormatValue() keeps enough digits that different values display differently", {
  expect_equal(rep_FormatValue(123.456789), "123.456789")
  expect_equal(rep_FormatValue(c(0.1 + 0.2, 0.3)), c("0.30000000000000004", "0.3"))
  expect_equal(rep_FormatValue(c(1 / 3, 36.6, NA, -2.5)), c("0.3333333333333333", "36.6", "NA", "-2.5"))
  expect_equal(rep_FormatValue(c(1e20, 1e-7)), c("100000000000000000000", "0.0000001"))
  expect_identical(rep_FormatValue(numeric(0)), character(0))
  # Each value is formatted alone, not with digits shared across the vector.
  expect_equal(rep_FormatValue(c(70, 70.123456)), c("70", "70.123456"))

  # The listing counts 0.1 + 0.2 and 0.3 as two values, as the engine does.
  lClass <- rep_Classify(rep_listings(rep_vs(list(A = c(0.1 + 0.2, 0.3, 0.3)))))
  expect_equal(lClass$measurements$value_text, c("0.30000000000000004", "0.3", "0.3"))
  expect_equal(lClass$participants$Numerator[lClass$participants$vital == "weight"], 0)
  df <- rep_VitalRows(lClass)
  expect_equal(df$n_unique[df$vital == "weight"], 2)
  expect_equal(df$values[df$vital == "weight"], "0.30000000000000004 0.3 0.3")
})
