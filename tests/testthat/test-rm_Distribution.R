test_that("distribution rows count evaluable participants by flag and reconcile with the overview (#345)", {
  lClass <- rm_Classify(rm_Fixture(), strFlagRule = "rate")
  dfParticipants <- lClass$participants
  dfOverview <- rm_OverviewRows(lClass)
  for (strLevel in c("study", "country", "site")) {
    df <- rm_DistributionRows(dfParticipants, strLevel, lClass$vitals)
    expect_true(all(df$Flag %in% c("Red", "Amber", "Green")), label = strLevel)
    expect_true(all(df$Level == strLevel))
    for (strVital in dfOverview$vital) {
      dfO <- dfOverview[dfOverview$vital == strVital, ]
      expect_equal(sum(df$n[df$vital == strVital]), dfO$evaluable, label = paste(strLevel, strVital))
      expect_equal(
        sum(df$n[df$vital == strVital & df$Flag != "Green"]),
        dfO$amber + dfO$red,
        label = paste(strLevel, strVital)
      )
    }
  }
})

test_that("study bars are labelled by vital and site bars carry their country, sorted by % flagged (#345)", {
  dfParticipants <- rm_Classify(rm_Fixture(), strFlagRule = "rate")$participants
  dfStudy <- rm_DistributionRows(dfParticipants, "study")
  # Height has no KRI but is flagged: D repeats 1 of 1 window.
  expect_equal(unique(dfStudy$GroupID), c("WT", "HR", "Ht"))
  expect_true(all(is.na(dfStudy$OuterGroupID)))

  dfSite <- rm_DistributionRows(dfParticipants, "site")
  dfWeight <- dfSite[dfSite$vital == "weight", ]
  # S3: 1 of 1 flagged; S1: 1 of 2; S2 has no evaluable participant.
  expect_equal(unique(dfWeight$GroupID), c("S3", "S1"))
  expect_equal(unique(dfWeight$OuterGroupID), c("JP", "US"))
  dfCountry <- rm_DistributionRows(dfParticipants, "country")
  expect_equal(unique(dfCountry$GroupID[dfCountry$vital == "weight"]), c("JP", "US"))
})

test_that("distribution spec maps flags to the flag colours in the given category order (#345)", {
  spec <- rm_DistributionSpec("site", c("S3", "S1"), "Weight (kri0020a)")
  expect_equal(spec$mapping, list(x = "GroupID", y = "n", fill = "Flag"))
  expect_equal(spec$scales$x$order, list("S3", "S1"))
  expect_equal(unlist(spec$scales$fill$colors), rm_FlagColors()[c("Red", "Amber", "Green")])
  expect_equal(spec$labels$title, "Weight (kri0020a)")
  expect_true(spec$zoom$enabled)
  expect_equal(rm_DistributionSpec("study")$orientation, "horizontal")
  expect_null(rm_DistributionSpec("study")$labels$captions)
})

test_that("site flags come from the latest site-level kri0020 results, keyed by vital and site (#345)", {
  lFlags <- rm_SiteFlags(rm_FixtureResults())
  expect_setequal(names(lFlags), c("weight", "pulse"))
  expect_equal(lFlags$weight, list(S1 = -2L, S2 = 0L, S3 = 1L))
  expect_equal(lFlags$pulse$S1, 2L)
  expect_length(rm_SiteFlags(NULL), 0)
  expect_length(rm_SiteFlags(data.frame(SnapshotDate = Sys.Date())), 0)
})
