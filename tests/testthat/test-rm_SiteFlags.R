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
