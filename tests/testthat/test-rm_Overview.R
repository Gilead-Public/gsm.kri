test_that("overview counts enrolled, evaluable and flagged participants by study, country and site (#344)", {
  df <- rm_OverviewRows(rm_Classify(rm_Fixture())$participants)
  row <- function(strLevel, strID, strVital) {
    as.list(df[df$Level == strLevel & df$GroupID == strID & df$vital == strVital, c("enrolled", "evaluable", "amber", "red")])
  }
  expect_setequal(unique(df$Level), c("study", "country", "site"))
  # Six KRI vitals at each of 1 study, 2 countries and 3 sites; height has no KRI.
  expect_equal(nrow(df), 6 * (1 + 2 + 3))
  expect_false("height" %in% df$vital)
  expect_equal(row("study", "STUDY1", "weight"), list(enrolled = 5L, evaluable = 3L, amber = 1L, red = 1L))
  expect_equal(row("study", "STUDY1", "pulse"), list(enrolled = 5L, evaluable = 2L, amber = 0L, red = 1L))
  expect_equal(row("country", "JP", "weight"), list(enrolled = 2L, evaluable = 1L, amber = 1L, red = 0L))
  expect_equal(row("site", "S2", "weight"), list(enrolled = 1L, evaluable = 0L, amber = 0L, red = 0L))
})

test_that("reconciliation sums participant N and D and compares them with the latest kri0020 results (#344)", {
  dfParticipants <- rm_Classify(rm_Fixture())$participants
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
  dfParticipants <- rm_Classify(rm_Fixture())$participants
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
