make_classified <- function() {
  tibble::tibble(
    subjid = c("A", "B", "C", "D", "E"),
    studyid = "ST01",
    country = c("USA", "USA", "CAN", "CAN", "USA"),
    invid = c("S1", "S1", "S2", "S2", "S1"),
    Category = factor(pd_CategoryLevels(90), levels = pd_CategoryLevels(90)),
    death_dy = c(20, 70, NA, NA, NA)
  )
}

test_that("pd_BucketRows returns long rows with n, pct, Level and no empty cells (#264)", {
  rows <- pd_BucketRows(make_classified(), 90, strGroupCol = "invid")
  expect_setequal(
    names(rows),
    c("GroupID", "OuterGroupID", "Category", "n", "pct", "Level")
  )
  # .drop = TRUE: only the category cells a site actually has. S1 holds A/B/E
  # (3 categories), S2 holds C/D (2). A category nobody lands in is absent from
  # the payload entirely, so gsm.viz builds no legend entry for it.
  expect_equal(nrow(rows), 5)
  expect_false(any(rows$n == 0))
  expect_equal(unique(rows$Level), "site")
  s1 <- rows[rows$GroupID == "S1", ]
  expect_equal(sum(s1$n), 3) # A, B, E at S1
  expect_equal(round(sum(s1$pct)), 100) # pct sums to 100 within group
})

test_that("pd_BucketRows carries OuterGroupID when strOuterCol set (#264)", {
  rows <- pd_BucketRows(
    make_classified(),
    90,
    strGroupCol = "invid",
    strOuterCol = "country"
  )
  expect_true(all(!is.na(rows$OuterGroupID)))
  expect_setequal(unique(rows$OuterGroupID), c("USA", "CAN"))
})

test_that("pd_BucketBarSpec builds a flat vertical stacked identity spec with fixed colors/order (#264)", {
  spec <- pd_BucketBarSpec(90, strGroupLabel = "Site")
  expect_equal(spec$mapping, list(x = "GroupID", y = "n", fill = "Category"))
  expect_equal(spec$orientation, "vertical")
  expect_equal(spec$position, "stack")
  expect_equal(spec$stat, "identity")
  expect_equal(spec$scales$y$label, "Subjects")
  expect_equal(spec$scales$x$label, "Site")
  # colors keyed by category label; fill order = display order (base->top)
  expect_equal(spec$scales$fill$colors, as.list(pd_CategoryColors(90)))
  expect_equal(unlist(spec$scales$fill$order), pd_DisplayOrder(90))
  # No faceting: country/site charts are flat bars, narrowed by click-filter.
  expect_null(spec$facet)
  # Zoom is opt-in: the default (study/country) charts carry no zoom key.
  expect_null(spec$zoom)
  # Theme is opt-in too, so gsm.viz's own theme defaults apply untouched.
  expect_null(spec$theme)
})

test_that("pd_BucketBarSpec emits zoom only when requested (#264)", {
  z <- list(enabled = TRUE, mode = "x")
  expect_equal(pd_BucketBarSpec(90, "Site", zoom = z)$zoom, z)
})

test_that("pd_BucketBarSpec passes theme through untouched (#264)", {
  # A passthrough rather than a per-option argument: gsm.viz owns the theme
  # vocabulary, so a new key there needs no change here.
  th <- list(dynamicCategoryAxis = TRUE)
  expect_equal(pd_BucketBarSpec(90, "Site", theme = th)$theme, th)
})

test_that("pd_BucketBarSpec turns on auto value labels (#264)", {
  spec <- pd_BucketBarSpec(90, strGroupLabel = "Site")
  # "auto" follows the native position control: counts while stat is identity,
  # percentages once the fill (100%) button sets stat = "percent".
  expect_equal(
    spec$annotations$labels$segment,
    list(display = TRUE, value = "auto")
  )
})

test_that("pd_BucketBarSpec keeps value labels when zoom is requested (#264)", {
  spec <- pd_BucketBarSpec(90, "Site", zoom = list(enabled = TRUE, mode = "x"))
  expect_true(spec$annotations$labels$segment$display)
})

test_that("pd_BucketBarSpec captions scroll-to-zoom on zoomable charts (#264)", {
  # The study chart is a single bar with no zoom, so there is nothing to note.
  expect_null(pd_BucketBarSpec(90, "Study")$labels)

  spec <- pd_BucketBarSpec(90, "Site", zoom = list(enabled = TRUE, mode = "x"))
  expect_equal(spec$labels$captions, "Scroll to zoom in; drag to pan.")
})

test_that("pd_BucketBarSpec drops the zoom caption when zoom is off (#264)", {
  # gsm.viz builds no zoom config unless enabled, so the note would be a lie.
  spec <- pd_BucketBarSpec(90, "Site", zoom = list(enabled = FALSE, mode = "x"))
  expect_null(spec$labels)
})

test_that("pd_BucketBarSpec attaches the tooltip formatter as a js_hook with no 'NA' string-compare {#288}", {
  spec <- pd_BucketBarSpec(90, strGroupLabel = "Site")
  expect_s3_class(spec$tooltip$formatter, "JS_EVAL")
  # gsm.vizr serializes with na = "null" (utils-serialize.R), so a missing
  # OuterGroupID (the study/country charts) arrives client-side as JS null, not
  # the literal "NA" string the old widget JS guarded against (na = "string").
  # paste()'d to a single string so a still-missing formatter (character(0))
  # fails the s3_class check above instead of a length-0 comparison here.
  formatter_code <- paste(as.character(spec$tooltip$formatter), collapse = "\n")
  expect_false(grepl("'NA'", formatter_code, fixed = TRUE))
})

test_that("gsm.vizr::bars() accepts pd_BucketBarSpec() and serializes the tooltip hook {#288}", {
  spec <- pd_BucketBarSpec(90, strGroupLabel = "Site")
  rows <- pd_BucketRows(make_classified(), 90, strGroupCol = "invid")
  widget <- gsm.vizr::bars(
    rows,
    spec,
    metadata = list(chartId = "pd-site-buckets")
  )
  expect_s3_class(widget, "htmlwidget")
  expect_false(is.null(widget$x$spec))
  expect_true(grepl("tooltip.formatter", widget$x$jsHooks, fixed = TRUE))
})
