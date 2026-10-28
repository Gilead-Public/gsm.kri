test_that("site flags come from the latest site-level kri0020 results, keyed by vital and site (#345)", {
  lFlags <- rm_SiteFlags(rm_FixtureResults())
  expect_setequal(names(lFlags), c("weight", "pulse"))
  expect_equal(lFlags$weight, list(S1 = -2L, S2 = 0L, S3 = 1L))
  expect_equal(lFlags$pulse$S1, 2L)
  expect_length(rm_SiteFlags(NULL), 0)
  expect_length(rm_SiteFlags(data.frame(SnapshotDate = Sys.Date())), 0)
})
