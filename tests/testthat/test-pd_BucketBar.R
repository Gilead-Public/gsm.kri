test_that("pd_BucketBar returns a plotly object {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:4),
    invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
    country = c("USA", "USA", "CAN", "CAN"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S4"),
    death_dy = c(20, 50, 120)
  )
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site"
  )
  expect_s3_class(p, "plotly")
})

test_that("pd_BucketBar uses RAG colors {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  colors_used <- p$x$attrs[[1]]$colors
  expect_equal(unname(colors_used["<=30d"]), colorScheme("red", "dark"))
  expect_equal(unname(colors_used["31-90d"]), colorScheme("amber", "dark"))
  expect_equal(
    unname(colors_used["Alive at 90d"]),
    colorScheme("green", "dark")
  )
})

test_that("pd_BucketBar buckets are correct at study level {#223}", {
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:4),
    invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
    country = c("USA", "USA", "CAN", "CAN"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S4"),
    death_dy = c(20, 50, 120)
  )
  df <- pd_BucketCounts(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "studyid"
  )
  total <- dplyr::filter(df, GroupID == "ST01")
  expect_equal(total$n[total$Bucket == "<=30d"], 1) # S1 @ day 20
  expect_equal(total$n[total$Bucket == "31-90d"], 1) # S2 @ day 50
  expect_equal(total$n[total$Bucket == "Alive at 90d"], 2) # S3 (no death) + S4 (day 120)
})

test_that("pd_BucketBar hover text shows bucket, count, and percent of enrolled {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:4),
    invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
    country = c("USA", "USA", "CAN", "CAN"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S4"),
    death_dy = c(20, 50, 120)
  )
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "studyid",
    strGroupLabel = "Study"
  )
  built <- plotly::plotly_build(p)
  texts <- unlist(lapply(built$x$data, function(d) d$customdata))
  # Bind the percent to its bucket so the assertion can't be satisfied by a
  # different bucket that happens to share the same count.
  expect_true(any(grepl("Bucket: <=30d<br>Subjects: 1 \\(25.0%\\)", texts))) # S1 of 4 enrolled
  expect_true(any(grepl(
    "Bucket: Alive at 90d<br>Subjects: 2 \\(50.0%\\)",
    texts
  ))) # S3 + S4 alive at 90d
})

test_that("pd_BucketBar validates inputs {#223}", {
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:4),
    invid = c("INV-1", "INV-1", "INV-2", "INV-2"),
    country = c("USA", "USA", "CAN", "CAN"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S4"),
    death_dy = c(20, 50, 120)
  )
  expect_error(
    pd_BucketBar(as.list(dfDeath), dfSubjects),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_BucketBar(dfDeath, as.list(dfSubjects)),
    "dfSubjects is not a data.frame"
  )
  expect_error(
    pd_BucketBar(dfDeath, dfSubjects, nWindowDays = -1),
    "nWindowDays must be a positive number"
  )
})

test_that("pd_BucketCounts carries a contiguous Outer tier when strOuterCol set {#223}", {
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:3),
    invid = c("INV-2", "INV-1", "INV-1"), # deliberately unsorted vs country
    country = c("CAN", "USA", "USA")
  )
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  df <- pd_BucketCounts(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_true("Outer" %in% names(df))
  # One row per (Outer, GroupID, Bucket): 2 sites x 3 buckets.
  expect_equal(nrow(df), 6)
  # Outer is contiguous so Plotly draws one bracket per country.
  expect_false(is.unsorted(df$Outer))
  # Every site keeps all three bucket rows (stack alignment depends on this).
  expect_true(all(table(df$GroupID) == 3))
})

test_that("pd_BucketCounts labels a missing parent 'Unknown' {#223}", {
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2"),
    invid = c("INV-1", "INV-2"),
    country = c("USA", NA)
  )
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  df <- pd_BucketCounts(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_true("Unknown" %in% df$Outer)
})

test_that("pd_BucketBar builds a 2-D multicategory x grouped by parent {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:3),
    invid = c("INV-2", "INV-1", "INV-1"),
    country = c("CAN", "USA", "USA"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site",
    strOuterCol = "country"
  )
  expect_s3_class(p, "plotly")
  built <- plotly::plotly_build(p)
  tr <- built$x$data[[1]]
  # x is the 2-D [[outer],[inner]] multicategory structure.
  expect_true(is.list(tr$x) && length(tr$x) == 2)
  # Inner tier is contiguous-by-country (CAN's site first, then USA's).
  expect_equal(tr$x[[1]], c("CAN", "USA")) # outer
  expect_equal(tr$x[[2]], c("INV-2", "INV-1")) # inner, aligned to outer
  # Each bucket trace carries a single RAG marker colour (no color= split).
  expect_equal(built$x$data[[1]]$marker$color, colorScheme("red", "dark"))
})

test_that("pd_BucketBar stays flat (one-tier) when strOuterCol is NULL {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:2), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  # Flat x is a plain character vector, not a 2-element list.
  expect_false(is.list(built$x$data[[1]]$x) && length(built$x$data[[1]]$x) == 2)
})
