make_classified <- function() {
  tibble::tibble(
    subjid = c("A", "B", "C", "D", "E"),
    studyid = "ST01",
    country = c("USA", "USA", "CAN", "CAN", "USA"),
    invid = c("S1", "S1", "S2", "S2", "S1"),
    Category = factor(
      pd_CategoryLevels(90),
      levels = pd_CategoryLevels(90)
    ),
    death_dy = c(20, 70, NA, NA, NA)
  )
}

test_that("pd_BucketCounts counts all five categories per group {#246}", {
  counts <- pd_BucketCounts(make_classified(), strGroupCol = "invid")
  expect_setequal(levels(counts$Bucket), unname(pd_CategoryLevels(90)))
  # every (group, bucket) cell present thanks to .drop = FALSE
  expect_equal(nrow(counts), length(unique(make_classified()$invid)) * 5)
  s1 <- dplyr::filter(counts, GroupID == "S1")
  expect_equal(sum(s1$n), 3) # A, B, E are at S1
})

test_that("pd_BucketCounts carries a contiguous Outer tier when strOuterCol set {#246}", {
  counts <- pd_BucketCounts(
    make_classified(),
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_true("Outer" %in% names(counts))
  # 2 sites x 5 categories, every cell kept by .drop = FALSE.
  expect_equal(nrow(counts), 10)
  # Rows are arranged by Outer, so each group's category rows stay together.
  expect_false(is.unsorted(counts$Outer))
  # Every site keeps all five category rows (stack alignment depends on this).
  expect_true(all(table(counts$GroupID) == 5))
})

test_that("pd_BucketCounts labels a missing parent 'Unknown' {#246}", {
  dfC <- make_classified()
  dfC$country[dfC$invid == "S2"] <- NA
  counts <- pd_BucketCounts(
    dfC,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_true("Unknown" %in% counts$Outer)
})

test_that("a pd_Classify-normalised missing country yields a clickable 'Unknown' bar resolvable in the site map {#221}", {
  subj <- tibble::tibble(
    subjid = c("A", "B"),
    studyid = "ST01",
    country = c(NA, "USA"), # A has no country
    invid = c("S1", "S2"),
    rgmn_dt = as.Date("2025-10-13")
  )
  death <- tibble::tibble(
    subjid = "A",
    death_dt = as.Date("2025-11-02"),
    death_dy = 20
  )
  dfC <- pd_Classify(
    subj,
    death,
    NULL,
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  # country is the bar's GroupID; the missing country must surface as a labelled
  # "Unknown" bar (not NA) so its JS click has a key in the country->site map.
  bar <- pd_BucketCounts(dfC, strGroupCol = "country")
  expect_true("Unknown" %in% as.character(bar$GroupID))
  # the report builds the site map from this same cohort, so every clickable bar
  # key resolves to sites -> the "Unknown" click can never collapse to empty.
  mapKeys <- unique(dplyr::distinct(dfC, country, invid)$country)
  expect_true(all(as.character(bar$GroupID) %in% mapKeys))
})

# pd_BucketBar() is retained (Plotly) but no longer used by the report, which now
# renders buckets via Widget_PrematureDeathBucketBar / pd_BucketBarSpec. The
# report-shape guarantees (fill colors/order, stacking, hover, drilldown payload)
# now live in test-pd_BucketBarSpec.R and test-Widget_PrematureDeathBucketBar.R;
# only a smoke test and input validation remain here.
test_that("pd_BucketBar returns a plotly object {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(make_classified(), strGroupCol = "invid")
  expect_s3_class(p, "plotly")
})

test_that("pd_BucketBar validates inputs {#246}", {
  expect_error(
    pd_BucketBar(as.list(make_classified())),
    "dfClassified is not a data.frame"
  )
  expect_error(
    pd_BucketBar(make_classified(), bRangeSlider = 1),
    "bRangeSlider must be logical"
  )
})
