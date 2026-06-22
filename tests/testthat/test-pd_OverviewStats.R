# Minimal classified-cohort fixture (only the columns pd_OverviewStats reads).
# lv[1] = "Death within 30 days", lv[2] = "Death within 31-90 days" are the two
# premature-death categories; lv[3:5] are non-premature.
lv <- pd_CategoryLevels(90)
dfClassified <- tibble::tibble(
  subjid = c("S1", "S2", "S3", "S4", "S5"),
  invid = c("INV-1", "INV-1", "INV-2", "INV-3", NA),
  Category = factor(c(lv[1], lv[2], lv[3], lv[4], lv[5]), levels = lv)
)

test_that("pd_OverviewStats counts enrolled, sites and premature from the cohort {#250}", {
  s <- pd_OverviewStats(dfClassified, nWindowDays = 90)
  expect_equal(s$nEnrolled, 5)
  expect_equal(s$nSites, 3) # INV-1, INV-2, INV-3; NA invid not counted
  expect_equal(s$nPremature, 2) # S1 + S2
  expect_equal(s$nPrematureRate, 40)
  expect_false(s$has_eligibility)
  expect_true(is.na(s$nIneligible))
  expect_true(is.na(s$nIneligibleRate))
})

test_that("pd_OverviewStats counts ineligible among premature deaths {#250}", {
  dfExclusion <- tibble::tibble(
    subjid = c("S1", "S2", "S3"),
    Source = c("Ineligible, Both Criteria", "Neither", "Neither")
  )
  s <- pd_OverviewStats(dfClassified, dfExclusion, nWindowDays = 90)
  expect_true(s$has_eligibility)
  # premature set = S1, S2; S1 ineligible, S2 eligible -> 1 of 2 = 50%
  expect_equal(s$nIneligible, 1)
  expect_equal(s$nIneligibleRate, 50)
})

test_that("pd_OverviewStats treats a premature subject with no exclusion row as not ineligible {#250}", {
  # S2 is absent from the exclusion frame -> Unknown, so not counted ineligible.
  dfExclusion <- tibble::tibble(subjid = "S1", Source = "EDC I/E only")
  s <- pd_OverviewStats(dfClassified, dfExclusion, nWindowDays = 90)
  expect_equal(s$nIneligible, 1) # only S1
  expect_equal(s$nIneligibleRate, 50)
})

test_that("pd_OverviewStats avoids divide-by-zero on an empty cohort {#250}", {
  s <- pd_OverviewStats(dfClassified[0, ], nWindowDays = 90)
  expect_equal(s$nEnrolled, 0)
  expect_equal(s$nSites, 0)
  expect_equal(s$nPremature, 0)
  expect_equal(s$nPrematureRate, 0) # 0, not NaN
  expect_false(s$has_eligibility)
})

test_that("pd_OverviewStats gives 0 ineligible rate when there are no premature deaths {#250}", {
  noDeaths <- tibble::tibble(
    subjid = c("A", "B"),
    invid = c("INV-9", "INV-9"),
    Category = factor(c(lv[4], lv[5]), levels = lv)
  )
  dfExclusion <- tibble::tibble(subjid = "A", Source = "Neither")
  s <- pd_OverviewStats(noDeaths, dfExclusion, nWindowDays = 90)
  expect_equal(s$nPremature, 0)
  expect_equal(s$nIneligible, 0)
  expect_equal(s$nIneligibleRate, 0) # 0, not NaN
})

test_that("pd_OverviewStats validates dfClassified {#250}", {
  expect_error(
    pd_OverviewStats("not a data.frame"),
    "dfClassified is not a data.frame"
  )
})
