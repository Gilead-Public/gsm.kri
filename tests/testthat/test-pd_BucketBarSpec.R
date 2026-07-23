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

test_that("pd_BucketRows returns long rows with n, pct, Level and preserves zero cells (#264)", {
  rows <- pd_BucketRows(make_classified(), 90, strGroupCol = "invid")
  expect_setequal(
    names(rows),
    c("GroupID", "OuterGroupID", "Category", "n", "pct", "Level")
  )
  # .drop = FALSE: every site x 5 categories present, incl zero cells.
  expect_equal(nrow(rows), length(unique(make_classified()$invid)) * 5)
  expect_true(any(rows$n == 0))
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
})

test_that("pd_BucketBarSpec emits zoom only when requested (#264)", {
  z <- list(enabled = TRUE, mode = "x")
  expect_equal(pd_BucketBarSpec(90, "Site", zoom = z)$zoom, z)
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
