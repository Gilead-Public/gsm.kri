make_classified <- function() {
  tibble::tibble(
    subjid = c("A", "B", "C", "D", "E"),
    studyid = "ST01",
    country = c("USA", "USA", "CAN", "CAN", "USA"),
    invid = c("S1", "S1", "S2", "S2", "S1"),
    Category = factor(
      pd_CategoryLevels(90)[c(1, 2, 3, 4, 5)],
      levels = pd_CategoryLevels(90)
    ),
    death_dy = c(20, 70, NA, NA, NA),
    discont_dy = c(NA, NA, 49, NA, NA),
    follow_up = c(200, 200, 200, 200, 40),
    x_anchor = c(20, 70, 49, 90, 40)
  )
}

test_that("pd_BucketCounts counts all five categories per group {#246}", {
  counts <- pd_BucketCounts(make_classified(), strGroupCol = "invid")
  expect_setequal(levels(counts$Bucket), pd_CategoryLevels(90))
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
  # Outer is contiguous so Plotly draws one bracket per country.
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
