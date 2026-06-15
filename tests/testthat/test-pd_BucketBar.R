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
  built <- plotly::plotly_build(p)
  cols <- setNames(
    lapply(built$x$data, function(d) d$marker$color),
    vapply(built$x$data, function(d) d$name, character(1))
  )
  expect_equal(unname(cols[["<=30d"]]), colorScheme("red", "dark"))
  expect_equal(unname(cols[["31-90d"]]), colorScheme("amber", "dark"))
  expect_equal(unname(cols[["Alive at 90d"]]), colorScheme("green", "dark"))
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

test_that("pd_BucketBar hover shows bucket, count, and percent of group {#223}", {
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
  tmpl <- setNames(
    vapply(built$x$data, function(d) d$hovertemplate, character(1)),
    vapply(built$x$data, function(d) d$name, character(1))
  )
  expect_match(tmpl[["<=30d"]], "Bucket: <=30d", fixed = TRUE)
  expect_match(
    tmpl[["<=30d"]],
    "Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)",
    fixed = TRUE
  )
  expect_no_match(tmpl[["<=30d"]], "Study:", fixed = TRUE) # flat chart names no group
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
  # Each tier is I()-wrapped (AsIs) so plotly keeps it an array under JSON
  # auto-unbox; strip the class with as.character before comparing values.
  expect_equal(as.character(tr$x[[1]]), c("CAN", "USA")) # outer
  expect_equal(as.character(tr$x[[2]]), c("INV-2", "INV-1")) # inner, aligned to outer
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

test_that("pd_BucketBar single-group multicategory x survives JSON auto-unboxing {#223}", {
  testthat::skip_if_not_installed("plotly")
  # plotly_build keeps the R list intact, so the unbox bug only surfaces after
  # JSON serialization: a single-group bucket would otherwise collapse
  # list(Outer, Inner) to a flat [outer, inner], breaking the 2-D axis in the
  # browser. Strip whitespace (plotly_json pretty-prints) then match the nested
  # form.
  dfSubjects <- tibble::tibble(
    subjid = "S1",
    invid = "INV-1",
    country = "USA",
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"x":[["USA"],["INV-1"]]', json, fixed = TRUE))
})

test_that("pd_BucketBar shows permanent inside labels with bucket, count, percent {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:4), studyid = "ST01")
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
  labels <- unlist(lapply(built$x$data, function(d) d$text))
  # 1 of 4 enrolled died <=30d.
  expect_true(any(grepl("<=30d: 1 (25.0%)", labels, fixed = TRUE)))
  # vapply + isTRUE (not unlist + all): unlist drops a NULL textposition, so a
  # trace that never received the attribute would slip through `all()`.
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$textposition == "inside"),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$constraintext == "none"),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$textangle == 0),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$insidetextanchor == "middle"),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$insidetextfont$color == "white"),
    logical(1)
  )))
})

test_that("pd_BucketBar blanks labels for zero-count buckets {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  # Only death is beyond the window -> all 3 subjects land in "Alive at 90d";
  # both premature buckets are zero.
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 200)
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  labels <- unlist(lapply(built$x$data, function(d) d$text))
  expect_false(any(grepl(": 0 (", labels, fixed = TRUE))) # no zero-count label rendered
  expect_true(any(labels == "")) # zero buckets are blanked
})

test_that("pd_BucketBar two-tier traces carry permanent labels {#223}", {
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
  built <- plotly::plotly_build(p)
  expect_true(all(vapply(
    built$x$data,
    function(d) !is.null(d$text),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$textposition == "inside"),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$constraintext == "none"),
    logical(1)
  )))
  expect_true(all(vapply(
    built$x$data,
    function(d) isTRUE(d$textangle == 0),
    logical(1)
  )))
  labels <- unlist(lapply(built$x$data, function(d) d$text))
  # INV-2 (CAN) has its single subject in <=30d -> 100% of that site's bar.
  expect_true(any(grepl("<=30d: 1 (", labels, fixed = TRUE)))
})

test_that("pd_BucketBar attaches a JS hook that hides labels overflowing their bar {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  hook <- paste(unlist(p$jsHooks$render), collapse = " ")
  expect_match(hook, "bartext-inside", fixed = TRUE)
  expect_match(hook, "plotly_afterplot", fixed = TRUE)

  dfSub2 <- tibble::tibble(
    subjid = paste0("S", 1:3),
    invid = c("I2", "I1", "I1"),
    country = c("CAN", "USA", "USA"),
    studyid = "ST01"
  )
  dfDeath2 <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p2 <- pd_BucketBar(
    dfDeath2,
    dfSub2,
    nWindowDays = 90,
    strGroupCol = "invid",
    strGroupLabel = "Site",
    strOuterCol = "country"
  )
  hook2 <- paste(unlist(p2$jsHooks$render), collapse = " ")
  expect_match(hook2, "bartext-inside", fixed = TRUE)
})

test_that("pd_BucketBar packs [count, pct] per point in customdata {#223}", {
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
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  # <=30d: 1 of 4 enrolled -> 25%; Alive at 90d: 2 of 4 -> 50%.
  expect_true(grepl('"customdata":[[1,25]]', json, fixed = TRUE))
  expect_true(grepl('"customdata":[[2,50]]', json, fixed = TRUE))
})

test_that("pd_BucketBar single-group customdata survives JSON auto-unboxing {#223}", {
  testthat::skip_if_not_installed("plotly")
  # One study, one subject dead at day 20 -> <=30d bucket, 1 of 1 -> 100%.
  # The pair must stay nested [[1,100]], NOT a flattened [1,100] (which the
  # browser would read as two single-value points).
  dfSubjects <- tibble::tibble(subjid = "S1", studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"customdata":[[1,100]]', json, fixed = TRUE))
})

test_that("pd_BucketBar builds one trace per bucket (no color= split) {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  trace_names <- vapply(built$x$data, function(d) d$name, character(1))
  expect_setequal(trace_names, c("<=30d", "31-90d", "Alive at 90d"))
})

test_that("pd_BucketBar two-tier tooltip names the group, not the unlabelled parent {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(
    subjid = paste0("S", 1:4),
    country = c("USA", "USA", "CAN", "CAN"),
    studyid = "ST01"
  )
  dfDeath <- tibble::tibble(subjid = c("S1", "S3"), death_dy = c(20, 50))
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "country",
    strGroupLabel = "Country",
    strOuterCol = "studyid"
  )
  tmpl <- plotly::plotly_build(p)$x$data[[1]]$hovertemplate
  expect_match(tmpl, "Country: %{customdata[2]}", fixed = TRUE)
  expect_match(
    tmpl,
    "Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)",
    fixed = TRUE
  )
  # No strOuterLabel -> the parent (study) tier is carried but never named.
  expect_no_match(tmpl, "customdata[3]", fixed = TRUE)
})

test_that("pd_BucketBar two-tier tooltip names parent then group when strOuterLabel set {#223}", {
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
    strOuterCol = "country",
    strOuterLabel = "Country"
  )
  tmpl <- plotly::plotly_build(p)$x$data[[1]]$hovertemplate
  expect_match(tmpl, "Country: %{customdata[3]}", fixed = TRUE)
  expect_match(tmpl, "Site: %{customdata[2]}", fixed = TRUE)
  # Parent line sits above the group line. hovertemplate is broadcast per point, so
  # compare positions within one element; as.integer strips regexpr's match.length.
  one <- tmpl[[1]]
  expect_lt(
    as.integer(regexpr("Country: %{customdata[3]}", one, fixed = TRUE)),
    as.integer(regexpr("Site: %{customdata[2]}", one, fixed = TRUE))
  )
})

test_that("pd_BucketBar two-tier customdata carries [count, pct, group, parent] nested {#223}", {
  testthat::skip_if_not_installed("plotly")
  # Single-group two-tier: the 4-tuple must stay nested
  # [[1,100,"INV-1","USA"]], not flatten under JSON auto-unbox -- the same hazard
  # the [count, pct] pair already guards.
  dfSubjects <- tibble::tibble(subjid = "S1", invid = "INV-1", country = "USA")
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    strGroupCol = "invid",
    strOuterCol = "country",
    strOuterLabel = "Country"
  )
  json <- gsub("[[:space:]]", "", plotly::plotly_json(p, jsonedit = FALSE))
  expect_true(grepl('"customdata":[[1,100,"INV-1","USA"]]', json, fixed = TRUE))
})

test_that("pd_BucketBar omits the range slider by default {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  built <- plotly::plotly_build(p)
  expect_null(built$x$layout$xaxis$rangeslider)
})

test_that("pd_BucketBar adds a thin x-axis range slider when bRangeSlider = TRUE {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90, bRangeSlider = TRUE)
  built <- plotly::plotly_build(p)
  rs <- built$x$layout$xaxis$rangeslider
  expect_true(isTRUE(rs$visible))
  expect_equal(rs$thickness, 0.04)
})

test_that("pd_BucketBar errors when bRangeSlider is not logical {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(20, 50))
  expect_error(
    pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90, bRangeSlider = 1),
    "bRangeSlider must be logical"
  )
})

test_that("pd_BucketBar scopes the overflow-hider to the main cartesian layer {#223}", {
  testthat::skip_if_not_installed("plotly")
  dfSubjects <- tibble::tibble(subjid = paste0("S", 1:3), studyid = "ST01")
  dfDeath <- tibble::tibble(subjid = "S1", death_dy = 20)
  p <- pd_BucketBar(dfDeath, dfSubjects, nWindowDays = 90)
  hook <- paste(unlist(p$jsHooks$render), collapse = " ")
  # The slider renders a duplicate of every bar label outside .cartesianlayer;
  # the hider must not touch those (getBBox under display:none is browser-flaky).
  expect_match(hook, ".cartesianlayer text.bartext-inside", fixed = TRUE)
})
