reason_slices <- function() ipc_ReasonRows(ipc_classified(), TRUE)
counts_of <- function(slice) stats::setNames(slice$n, slice$reason)

test_that("reasons split, trim and count each participant once per reason (#320)", {
  r <- reason_slices()
  expect_equal(
    counts_of(r$study),
    c(
      "Adverse Event" = 2L,
      "Not yet recorded" = 1L,
      "Physician Decision" = 1L,
      "Withdrawal by Subject" = 1L
    )
  )
})

test_that("reasons are ordered by frequency, ties alphabetical (#320)", {
  expect_equal(
    reason_slices()$order,
    c(
      "Adverse Event",
      "Not yet recorded",
      "Physician Decision",
      "Withdrawal by Subject"
    )
  )
})

test_that("a reason without a discontinuation date is not counted (#320)", {
  expect_false("Lack of Efficacy" %in% reason_slices()$order)
})

test_that("every slice lists every reason, zeros included (#320)", {
  r <- reason_slices()
  expect_equal(
    counts_of(r$country$Poland),
    c(
      "Adverse Event" = 1L,
      "Not yet recorded" = 0L,
      "Physician Decision" = 1L,
      "Withdrawal by Subject" = 0L
    )
  )
  expect_equal(r$country$Poland$reason, r$order)
  expect_equal(r$zero$n, rep(0L, 4))
  expect_equal(r$zero$pct, rep(0, 4))
})

test_that("pct is over the dosed participants in scope (#320)", {
  r <- reason_slices()
  expect_equal(r$study$pct[r$study$reason == "Adverse Event"], 100 * 2 / 12)
  expect_equal(r$country$Poland$pct[1], 100 * 1 / 2)
  # Unknown has no dosed participant: 0, not NaN.
  expect_equal(r$country$Unknown$pct, rep(0, 4))
})

test_that("slices exist for every country and every country/site pair (#320)", {
  r <- reason_slices()
  expect_setequal(names(r$country), c("Canada", "Japan", "Poland", "Unknown"))
  expect_setequal(names(r$site$Japan), c("JP01", "JP02"))
  expect_equal(names(r$site$Unknown), "Unknown")
  expect_equal(counts_of(r$site$Japan$JP02)[["Not yet recorded"]], 1L)
})

test_that("without discontinuation data there are no reason slices (#320)", {
  expect_null(ipc_ReasonRows(ipc_classified(bPTD = FALSE), FALSE))
})

test_that("no discontinuations give an empty order (#320)", {
  df <- ipc_classified()
  df$status[df$status == "Premature treatment discontinuation"] <- "Ongoing"
  r <- ipc_ReasonRows(df, TRUE)
  expect_length(r$order, 0)
  expect_equal(nrow(r$study), 0)
})

test_that("the reason spec pins the frequency order on a horizontal bar (#320)", {
  spec <- ipc_ReasonBarSpec(reason_slices()$order)
  expect_equal(spec$orientation, "horizontal")
  expect_equal(spec$stat, "identity")
  expect_equal(unlist(spec$scales$x$order), reason_slices()$order)
  expect_equal(spec$scales$y$label, "% of dosed participants")
  expect_s3_class(spec$annotations$labels$segment$formatter, "JS_EVAL")
  expect_s3_class(spec$tooltip$formatter, "JS_EVAL")
})
