test_that("pd_ReasonRows flattens a reason slice to reason/n/hover (#264)", {
  slice <- list(reason = c("A", "B"), n = c(3L, 1L), hover = c("hA", "hB"))
  rows <- pd_ReasonRows(slice)
  expect_setequal(names(rows), c("reason", "n", "hover"))
  expect_equal(rows$n, c(3L, 1L))
})

test_that("pd_ReasonBarSpec is horizontal with reason on the category axis (#264)", {
  spec <- pd_ReasonBarSpec()
  expect_equal(spec$orientation, "horizontal")
  # gsm.viz reads the category axis from the x mapping. sort/sortDir are inert
  # without nCategories, so category ORDER is controlled by scales$x$order.
  expect_equal(spec$mapping, list(x = "reason", y = "n"))
  expect_equal(spec$scales$y$label, "Premature Deaths")
  expect_null(spec$scales$x$order) # no order pin when reason_order is NULL
  expect_null(spec$color) # no color pin — gsm.viz default
})

test_that("pd_ReasonBarSpec pins the category order when reason_order is supplied (#264)", {
  spec <- pd_ReasonBarSpec(
    reason_order = c("Disease progression", "AE", "Unknown")
  )
  # An explicit order preserves the count sort the old Plotly chart got from
  # stats::reorder(reason, n); a plain list so jsonlite emits a JSON array.
  expect_equal(
    spec$scales$x$order,
    list("Disease progression", "AE", "Unknown")
  )
})
