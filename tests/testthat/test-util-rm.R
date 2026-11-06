test_that("metric metadata reads the kri0020 and cou0020 rows with one warning format", {
  dfMetrics <- data.frame(
    ID = c("kri0020a", "cou0020b", "kri0001"),
    WindowLength = c(3, NA, 9),
    Threshold = c("0.2,0.3", "0.2,0.3", "1,2"),
    AccrualThreshold = c(NA, 4, 30)
  )
  expect_equal(rm_MetricMeta(dfMetrics, "WindowLength"), 3)
  expect_equal(rm_MetricMeta(dfMetrics, "Threshold"), "0.2,0.3")
  expect_equal(rm_MetricMeta(dfMetrics, "AccrualThreshold"), 4)
  expect_null(rm_MetricMeta(dfMetrics, "Flag"))
  expect_null(rm_MetricMeta(NULL, "WindowLength"))
  expect_null(rm_MetricMeta(dfMetrics[3, ], "WindowLength"))

  dfMetrics$AccrualThreshold <- c(5, 4, 30)
  expect_warning(
    expect_equal(rm_MetricMeta(dfMetrics, "AccrualThreshold"), 5),
    "kri0020/cou0020 metrics use different AccrualThreshold values"
  )
  dfMetrics$WindowLength <- c(3, 4, 9)
  expect_warning(rm_WindowLength(dfMetrics), "different WindowLength values")
  dfMetrics$Threshold <- c("0.2,0.3", "0.1,0.3", "1,2")
  expect_warning(rm_FlagThresholds("rate", dfMetrics = dfMetrics), "different Threshold values")
})

test_that("country-only metrics supply the report settings", {
  dfMetrics <- data.frame(
    ID = "cou0020a", WindowLength = 2, Threshold = "0.1,0.4", AccrualThreshold = 5
  )
  expect_equal(rm_WindowLength(dfMetrics)$window_length, 2)
  expect_equal(rm_FlagThresholds("rate", dfMetrics = dfMetrics), c(0.1, 0.4))
  expect_equal(rm_SiteRule(dfMetrics), list(thresholds = c(0.1, 0.4), accrual = 5))
})

test_that("flag severity orders Red, Amber, Green, Not evaluable", {
  expect_identical(
    rm_FlagSeverity(factor(c("Green", "Not evaluable", "Red", "Amber"))),
    c(1L, 0L, 3L, 2L)
  )
})

test_that("rm_FormatValue() drops trailing zeros without scientific notation", {
  expect_equal(rm_FormatValue(c(72, 72.50, 0.000012, 1234567)), c("72", "72.5", "0.000012", "1234567"))
})
