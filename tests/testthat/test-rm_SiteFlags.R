test_that("site flags come from the KRI where it has results and from the site rule otherwise (#344, #345)", {
  lClass <- rm_Classify(rm_Fixture())
  # Without results every vital uses the rule: S1 weight 2/4 = 50%, S3 1/4 = 25%,
  # S1 HR 1/3 = 33%; S2 and the other vitals are below the accrual of 3 windows.
  df <- rm_SiteFlagRows(lClass)
  expect_true(all(df$source == "report"))
  expect_equal(df$flag[df$vital == "weight"], c(2L, NA, 1L))
  expect_equal(df$flag[df$vital == "pulse"], c(2L, NA, NA))
  expect_equal(df$Denominator[df$vital == "weight"], c(4, 0, 4))
  expect_equal(unique(df$country[df$invid == "S3"]), "JP")

  # KRI flags are absolute; a site without a result is not evaluated.
  dfResults <- rm_FixtureResults()
  dfResults <- dfResults[!(dfResults$MetricID == "Analysis_kri0020a" & dfResults$GroupID == "S2"), ]
  df <- rm_SiteFlagRows(lClass, dfResults)
  expect_equal(df$flag[df$vital == "weight"], c(2L, NA, 1L))
  expect_equal(unique(df$source[df$vital == "weight"]), "KRI")
  expect_equal(unique(df$source[df$vital == "sysbp"]), "report")

  # A lower accrual threshold from the metrics lets S3 height (1/1) be evaluated.
  dfMetrics <- data.frame(ID = "kri0020a", Threshold = "0.2,0.3", AccrualThreshold = 1)
  df <- rm_SiteFlagRows(lClass, dfMetrics = dfMetrics)
  expect_equal(df$flag[df$vital == "height"], c(NA, NA, 2L))
})

test_that("a site that spans countries is one site row, counted once in the study (#344)", {
  lClass <- suppressWarnings(rm_Classify(rm_FixtureSplit()))
  df <- rm_SiteFlagRows(lClass)
  dfW <- df[df$vital == "weight", ]
  expect_equal(dfW$invid, c("S1", "S2"))
  expect_equal(dfW$country, c("US", "JP, US"))
  expect_equal(dfW$Numerator, c(2, 3))
  expect_equal(dfW$Denominator, c(2, 5))
  # S1 is below the accrual of 3 windows; S2 is 3/5 = 60%, Red.
  expect_equal(dfW$flag, c(NA, 2L))
})

test_that("the site rule reads the kri0020 thresholds and accrual from the metrics (#344)", {
  expect_equal(rm_SiteRule(), list(thresholds = c(0.2, 0.3), accrual = 3))
  dfMetrics <- data.frame(
    ID = c("kri0020a", "kri0001"),
    Threshold = c("0.1,0.4", "1,2"),
    AccrualThreshold = c(5, 30)
  )
  expect_equal(rm_SiteRule(dfMetrics), list(thresholds = c(0.1, 0.4), accrual = 5))
})

test_that("report site flags match the kri0020 workflow flags for every KRI vital (#345)", {
  TestAtLogLevel()
  vSuffix <- c(weight = "a", pulse = "b", sysbp = "c", diabp = "d", resp = "e", temp = "f")
  lClass <- rm_Classify(list(
    Mapped_VS = mapped_data$Mapped_VS,
    Mapped_SUBJ = mapped_data$Mapped_SUBJ
  ))
  lResults <- workr::RunWorkflows(kri_workflow(paste0("kri0020", vSuffix)), mapped_data)
  # Without results every vital is flagged in the report.
  df <- rm_SiteFlagRows(lClass)
  for (strVital in names(vSuffix)) {
    dfVital <- df[df$vital == strVital, ]
    dfKRI <- lResults[[paste0("Analysis_kri0020", vSuffix[[strVital]])]]$Analysis_Flagged
    vKRI <- as.integer(dfKRI$Flag[match(dfVital$invid, dfKRI$GroupID)])
    expect_equal(dfVital$flag, vKRI, label = strVital)
  }
  expect_true(any(df$flag == 2L, na.rm = TRUE))
})

test_that("site flags handle no windows, the accrual boundary and equal thresholds quietly (#345)", {
  lClass <- rm_Classify(rm_Fixture())
  weight_flags <- function(dfMetrics) {
    df <- rm_SiteFlagRows(lClass, dfMetrics = dfMetrics)
    df$flag[df$vital == "weight"]
  }
  # No participant has a window for these vitals, so no site is evaluated.
  lNone <- lClass
  lNone$participants$Numerator <- 0
  lNone$participants$Denominator <- 0
  expect_silent(df <- rm_SiteFlagRows(lNone))
  expect_true(all(is.na(df$flag)))

  # S1 and S3 weight have exactly 4 windows: evaluated at an accrual of 4, not 5.
  dfMetrics <- data.frame(ID = "kri0020a", Threshold = "0.2,0.3", AccrualThreshold = 4)
  expect_equal(weight_flags(dfMetrics), c(2L, NA, 1L))
  dfMetrics$AccrualThreshold <- 5
  expect_equal(weight_flags(dfMetrics), c(NA_integer_, NA, NA))

  # Equal Amber and Red thresholds leave no Amber: S3 (25%) is Red at 25%.
  dfMetrics <- data.frame(ID = "kri0020a", Threshold = "0.25,0.25", AccrualThreshold = 3)
  expect_equal(weight_flags(dfMetrics), c(2L, NA, 2L))
})

test_that("site flags come from the latest site-level kri0020 results, keyed by vital and site (#345)", {
  lFlags <- rm_SiteFlags(rm_FixtureResults())
  expect_setequal(names(lFlags), c("weight", "pulse"))
  expect_equal(lFlags$weight, list(S1 = -2L, S2 = 0L, S3 = 1L))
  expect_equal(lFlags$pulse$S1, 2L)
  expect_length(rm_SiteFlags(NULL), 0)
  expect_length(rm_SiteFlags(data.frame(SnapshotDate = Sys.Date())), 0)
})

test_that("an all-missing latest snapshot is not evaluated, not an older flag (#345)", {
  df <- rm_FixtureResults()
  df$Flag[df$MetricID == "Analysis_kri0020a" & df$SnapshotDate == max(df$SnapshotDate)] <- NA
  df$Flag[df$MetricID == "Analysis_kri0020a" & df$SnapshotDate < max(df$SnapshotDate)] <- 2
  lFlags <- rm_SiteFlags(df)
  expect_true("weight" %in% names(lFlags))
  expect_true(all(is.na(unlist(lFlags$weight))))
  expect_equal(lFlags$pulse$S1, 2L)
})

test_that("each metric uses its own latest snapshot (#345)", {
  df <- rm_FixtureResults()
  df <- df[!(df$MetricID == "Analysis_kri0020b" & df$SnapshotDate == max(df$SnapshotDate)), ]
  lFlags <- rm_SiteFlags(df)
  expect_equal(lFlags$weight$S1, -2L)
  expect_equal(lFlags$pulse$S1, 0L)
})
