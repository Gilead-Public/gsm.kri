test_that("overview figures come in report order over their denominators (#320)", {
  stats <- ipc_OverviewStats(ipc_classified(), TRUE)
  expect_equal(
    stats$label,
    c(
      "Total enrolled",
      "Confirmed dosed",
      "Potential IP non-starter - within window",
      "Potential IP non-starter - outside window",
      "Confirmed IP non-starter",
      "Confirmed with consent withdrawn",
      "Ongoing",
      "Study complete",
      "Premature treatment discontinuation"
    )
  )
  expect_equal(stats$n, c(24, 12, 3, 2, 3, 1, 6, 2, 4))
  expect_equal(stats$base, c(NA, rep("enrolled", 5), rep("dosed", 3)))
  expect_equal(
    stats$pct,
    c(
      NA,
      50,
      12.5,
      100 * 2 / 24,
      12.5,
      100 / 24,
      50,
      100 * 2 / 12,
      100 * 4 / 12
    )
  )
})

test_that("consent withdrawn counts Confirmed non-starters only (#320)", {
  df <- ipc_classified()
  # P20 withdrew consent but completed the study: flagged, not counted here.
  expect_equal(df$consent_withdrawn[df$subjid == "P20"], "Y")
  stats <- ipc_OverviewStats(df, TRUE)
  expect_equal(stats$n[stats$label == "Confirmed with consent withdrawn"], 1)
})

test_that("without discontinuation data its figure is NA (#320)", {
  stats <- ipc_OverviewStats(ipc_classified(bPTD = FALSE), FALSE)
  ptd <- stats[stats$label == "Premature treatment discontinuation", ]
  expect_true(is.na(ptd$n))
  expect_true(is.na(ptd$pct))
})

test_that("zero denominators give NA, never NaN (#320)", {
  stats <- ipc_OverviewStats(ipc_classified()[0, ], TRUE)
  expect_true(all(stats$n == 0))
  expect_true(all(is.na(stats$pct)))
  expect_false(any(is.nan(stats$pct)))
})
