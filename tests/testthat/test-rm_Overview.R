test_that("study overview has one row per vital with site and participant counts for the whole study (#344)", {
  lClass <- rm_Classify(rm_Fixture(), strFlagRule = "rate")
  df <- rm_OverviewRows(lClass, rm_SiteFlagRows(lClass, rm_FixtureResults()))
  row <- function(strVital, vCols) as.list(df[df$vital == strVital, vCols])
  vP <- c("enrolled", "evaluable", "amber", "red")
  vS <- c("site_source", "sites", "sites_evaluated", "site_amber", "site_red")
  # Every vital in the data, KRI or not.
  expect_equal(df$vital, c("weight", "pulse", "sysbp", "diabp", "resp", "temp", "height"))
  expect_equal(df$metric[df$vital == "height"], NA_character_)
  expect_equal(row("weight", vP), list(enrolled = 5L, evaluable = 3L, amber = 1L, red = 1L))
  expect_equal(row("pulse", vP), list(enrolled = 5L, evaluable = 2L, amber = 0L, red = 1L))
  expect_equal(row("height", vP), list(enrolled = 5L, evaluable = 1L, amber = 0L, red = 1L))
  # Weight takes the latest KRI flags: S1 Red, S2 Green, S3 Amber.
  expect_equal(
    row("weight", vS),
    list(site_source = "KRI", sites = 3L, sites_evaluated = 3L, site_amber = 1L, site_red = 1L)
  )
  # Height has no KRI and no site reaches the accrual threshold of 3 windows.
  expect_equal(
    row("height", vS),
    list(site_source = "report", sites = 3L, sites_evaluated = 0L, site_amber = 0L, site_red = 0L)
  )
})

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

test_that("the site rule reads the kri0020 thresholds and accrual from the metrics (#344)", {
  expect_equal(rm_SiteRule(), list(thresholds = c(0.2, 0.3), accrual = 3))
  dfMetrics <- data.frame(
    ID = c("kri0020a", "kri0001"),
    Threshold = c("0.1,0.4", "1,2"),
    AccrualThreshold = c(5, 30)
  )
  expect_equal(rm_SiteRule(dfMetrics), list(thresholds = c(0.1, 0.4), accrual = 5))
})

test_that("reconciliation sums participant N and D and compares them with the latest kri0020 results (#344)", {
  dfParticipants <- rm_Classify(rm_Fixture(), strFlagRule = "rate")$participants
  df <- rm_Reconcile(dfParticipants, rm_FixtureResults())
  expect_equal(df$vital, c("weight", "pulse"))
  expect_equal(df$Numerator, c(3, 1))
  expect_equal(df$Denominator, c(8, 3))
  expect_true(all(df$match))

  dfResults <- rm_FixtureResults()
  dfResults$Numerator[nrow(dfResults)] <- 5
  df <- rm_Reconcile(dfParticipants, dfResults)
  expect_equal(df$match, c(TRUE, FALSE))
  expect_equal(df$kri_Numerator[2], 6)
})

test_that("reconciliation is skipped without kri0020 results (#344)", {
  dfParticipants <- rm_Classify(rm_Fixture(), strFlagRule = "rate")$participants
  expect_null(rm_Reconcile(dfParticipants, NULL))
  expect_null(rm_Reconcile(dfParticipants, data.frame(SnapshotDate = Sys.Date())))
  dfOther <- rm_FixtureResults()
  dfOther$MetricID <- "Analysis_kri0001"
  expect_null(rm_Reconcile(dfParticipants, dfOther))
})

test_that("participant counts reconcile with the kri0020a-f workflows on the qualification data (#344)", {
  TestAtLogLevel()
  vIDs <- paste0("kri0020", letters[1:6])
  lResults <- workr::RunWorkflows(kri_workflow(vIDs), mapped_data)
  dfResults <- do.call(rbind, lapply(vIDs, function(id) {
    df <- lResults[[paste0("Analysis_", id)]]$Analysis_Summary
    data.frame(MetricID = paste0("Analysis_", id), Numerator = df$Numerator, Denominator = df$Denominator)
  }))
  lClass <- rm_Classify(mapped_data[c("Mapped_VS", "Mapped_SUBJ")])
  df <- rm_Reconcile(lClass$participants, dfResults)
  expect_equal(df$metric, vIDs)
  expect_gt(sum(df$Numerator), 0)
  expect_true(all(df$match))
})
