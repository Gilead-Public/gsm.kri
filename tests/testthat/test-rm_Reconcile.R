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

test_that("participant counts reconcile with the cou0020a-f workflows too", {
  TestAtLogLevel()
  vIDs <- paste0(rep(c("kri0020", "cou0020"), each = 6), letters[1:6])
  lResults <- workr::RunWorkflows(kri_workflow(vIDs), mapped_data)
  dfResults <- do.call(rbind, lapply(vIDs, function(id) {
    df <- lResults[[paste0("Analysis_", id)]]$Analysis_Summary
    data.frame(MetricID = paste0("Analysis_", id), Numerator = df$Numerator, Denominator = df$Denominator)
  }))
  lClass <- rm_Classify(mapped_data[c("Mapped_VS", "Mapped_SUBJ")])
  df <- rm_Reconcile(lClass$participants, dfResults)
  # Each measure lists its site metric, then its country metric.
  expect_equal(df$metric, as.vector(rbind(vIDs[1:6], vIDs[7:12])))
  expect_equal(df$vital, rep(c("weight", "pulse", "sysbp", "diabp", "resp", "temp"), each = 2))
  expect_true(all(df$match))

  # Country results alone reconcile, and a country mismatch is reported.
  dfCountry <- dfResults[grepl("cou", dfResults$MetricID), ]
  dfCountry$Numerator[dfCountry$MetricID == "Analysis_cou0020a"][1] <- -1
  df <- rm_Reconcile(lClass$participants, dfCountry)
  expect_equal(df$metric, vIDs[7:12])
  expect_equal(df$match, c(FALSE, rep(TRUE, 5)))
})
