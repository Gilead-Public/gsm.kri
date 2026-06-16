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

test_that("pd_BucketBar returns a plotly object {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(make_classified(), strGroupCol = "invid")
  expect_s3_class(p, "plotly")
})

test_that("pd_BucketBar shows count labels and five separate legend categories {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(
    make_classified(),
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  b <- plotly::plotly_build(p)

  # FIX-2: default (count) on-bar text is the bare count (or "" for zero).
  texts <- unlist(lapply(b$x$data, function(tr) tr$text))
  texts <- texts[nzchar(texts)]
  expect_true(all(grepl("^[0-9]+$", texts)))

  # The two death categories are separate legend entries, NOT joined under a
  # "Death within 90 days" group title.
  grouptitles <- vapply(
    b$x$data,
    function(tr) {
      gt <- tr$legendgrouptitle$text
      if (is.null(gt)) NA_character_ else gt
    },
    character(1)
  )
  expect_false("Death within 90 days" %in% grouptitles)

  # Each of the five categories is its own legend entry, named by its full label.
  names <- vapply(b$x$data, function(tr) tr$name, character(1))
  expect_setequal(names, pd_CategoryLevels(90))
  expect_equal(length(b$x$data), 5)
})

test_that("pd_BucketBar colors the five categories from pd_CategoryColors {#246}", {
  testthat::skip_if_not_installed("plotly")
  b <- plotly::plotly_build(pd_BucketBar(make_classified()))
  cols <- unname(pd_CategoryColors(90))
  # traces are added in pd_CategoryLevels() order, so colors line up by index.
  for (i in seq_len(5)) {
    expect_equal(b$x$data[[i]]$marker$color, cols[i])
  }
})

test_that("pd_BucketBar hover names the category, count, and percent {#246}", {
  testthat::skip_if_not_installed("plotly")
  b <- plotly::plotly_build(pd_BucketBar(
    make_classified(),
    strGroupCol = "studyid"
  ))
  tmpl <- b$x$data[[1]]$hovertemplate
  expect_match(tmpl, "Category: ", fixed = TRUE)
  expect_match(
    tmpl,
    "Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)",
    fixed = TRUE
  )
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

test_that("pd_BucketBar builds a 2-D multicategory x grouped by parent {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(
    make_classified(),
    strGroupCol = "invid",
    strGroupLabel = "Site",
    strOuterCol = "country"
  )
  tr <- plotly::plotly_build(p)$x$data[[1]]
  # x is the 2-D [[outer],[inner]] multicategory structure.
  expect_true(is.list(tr$x) && length(tr$x) == 2)
})

test_that("pd_BucketBar single-group multicategory x survives JSON auto-unboxing {#246}", {
  testthat::skip_if_not_installed("plotly")
  dfC <- make_classified()[1, ]
  dfC$invid <- "S1"
  dfC$country <- "USA"
  p <- pd_BucketBar(dfC, strGroupCol = "invid", strOuterCol = "country")
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"x":[["USA"],["S1"]]', json, fixed = TRUE))
})

test_that("pd_BucketBar packs [count, pct] per point in customdata {#246}", {
  testthat::skip_if_not_installed("plotly")
  # All five subjects in ST01: each category is 1 of 5 -> 20%.
  p <- pd_BucketBar(make_classified(), strGroupCol = "studyid")
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"customdata":[[1,20]]', json, fixed = TRUE))
})

test_that("pd_BucketBar single-group customdata survives JSON auto-unboxing {#246}", {
  testthat::skip_if_not_installed("plotly")
  # One study, one subject in the <=30d category -> 1 of 1 -> 100%.
  dfC <- make_classified()[1, ]
  p <- pd_BucketBar(dfC, strGroupCol = "studyid")
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"customdata":[[1,100]]', json, fixed = TRUE))
})

test_that("pd_BucketBar omits the range slider by default {#246}", {
  testthat::skip_if_not_installed("plotly")
  b <- plotly::plotly_build(pd_BucketBar(make_classified()))
  expect_null(b$x$layout$xaxis$rangeslider)
})

test_that("pd_BucketBar adds a thin styled x-axis range slider when bRangeSlider = TRUE {#246}", {
  testthat::skip_if_not_installed("plotly")
  b <- plotly::plotly_build(pd_BucketBar(
    make_classified(),
    bRangeSlider = TRUE
  ))
  rs <- b$x$layout$xaxis$rangeslider
  expect_true(isTRUE(rs$visible))
  expect_equal(rs$thickness, 0.04)
  expect_equal(rs$bgcolor, "#f2f2f2")
  expect_equal(rs$bordercolor, colorScheme("gray", "dark"))
  expect_equal(rs$borderwidth, 1)
})

test_that("pd_BucketBar two-tier tooltip names the parent when strOuterLabel set {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(
    make_classified(),
    strGroupCol = "invid",
    strGroupLabel = "Site",
    strOuterCol = "country",
    strOuterLabel = "Country"
  )
  tmpl <- plotly::plotly_build(p)$x$data[[1]]$hovertemplate
  expect_match(tmpl, "Country: %{customdata[3]}", fixed = TRUE)
  expect_match(tmpl, "Site: %{customdata[2]}", fixed = TRUE)
})

test_that("pd_BucketBar attaches a JS hook scoped to the main cartesian layer {#246}", {
  testthat::skip_if_not_installed("plotly")
  p <- pd_BucketBar(make_classified())
  hook <- paste(unlist(p$jsHooks$render), collapse = " ")
  expect_match(hook, ".cartesianlayer text.bartext-inside", fixed = TRUE)
  expect_match(hook, "plotly_afterplot", fixed = TRUE)
})
