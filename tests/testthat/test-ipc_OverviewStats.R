test_that("overview figures come in report order over their denominators (#320, #332)", {
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
      "Treatment ongoing",
      "Treatment complete per protocol",
      "Premature treatment discontinuation",
      "Potential premature treatment discontinuation"
    )
  )
  expect_equal(stats$n, c(29, 17, 3, 2, 3, 1, 7, 2, 5, 2))
  expect_equal(stats$base, c(NA, rep("enrolled", 5), rep("dosed", 4)))
  expect_equal(
    stats$pct,
    c(NA, 100 * c(17, 3, 2, 3, 1) / 29, 100 * c(7, 2, 5, 2) / 17)
  )
})

test_that("consent withdrawn counts Confirmed non-starters only (#320)", {
  df <- ipc_classified()
  # P20 withdrew consent while dosed: flagged, not counted here.
  expect_equal(df$consent_withdrawn[df$subjid == "P20"], "Y")
  stats <- ipc_OverviewStats(df, TRUE)
  expect_equal(stats$n[stats$label == "Confirmed with consent withdrawn"], 1)
})

test_that("without drv_drg_completion the four dosed status figures are NA (#332)", {
  stats <- ipc_OverviewStats(ipc_classified(bPTD = FALSE), FALSE)
  bDosed <- stats$base %in% "dosed"
  expect_equal(sum(bDosed), 4)
  expect_true(all(is.na(stats$n[bDosed])))
  expect_true(all(is.na(stats$pct[bDosed])))
  expect_equal(stats$n[stats$label == "Confirmed dosed"], 17)
})

test_that("zero denominators give NA, never NaN (#320)", {
  stats <- ipc_OverviewStats(ipc_classified()[0, ], TRUE)
  expect_true(all(stats$n == 0))
  expect_true(all(is.na(stats$pct)))
  expect_false(any(is.nan(stats$pct)))
})
