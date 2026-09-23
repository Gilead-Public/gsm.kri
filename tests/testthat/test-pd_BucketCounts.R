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

test_that("pd_BucketCounts emits only the category cells that occur {#246}", {
  counts <- pd_BucketCounts(make_classified(), strGroupCol = "invid")
  # The Bucket factor still carries the whole vocabulary -- .drop = TRUE drops
  # unused (group, bucket) COMBINATIONS, not the levels themselves -- so colour
  # and display order still key off all five.
  expect_setequal(levels(counts$Bucket), unname(pd_CategoryLevels(90)))
  # One row per observed pair: S1 holds A/B/E (3 categories), S2 holds C/D (2).
  expect_equal(nrow(counts), 5)
  expect_false(any(counts$n == 0))
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
  # Only observed (Outer, group, bucket) cells: S1 holds 3 categories, S2 holds 2.
  expect_equal(nrow(counts), 5)
  # Rows are arranged by Outer, so each group's category rows stay together.
  expect_false(is.unsorted(counts$Outer))
  expect_equal(as.vector(table(counts$GroupID)[c("S1", "S2")]), c(3L, 2L))
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
