test_that("pd_PctLabel formats percentages and guards bad denominators {#223}", {
  expect_equal(pd_PctLabel(3, 7), "42.9%")
  expect_equal(pd_PctLabel(c(1, 3), 4), c("25.0%", "75.0%"))
  expect_equal(pd_PctLabel(1, 0), "\u2014")
  expect_equal(pd_PctLabel(1, NA), "\u2014")
  expect_equal(pd_PctLabel(NA, 4), "\u2014")
})

test_that("pd_YesNo maps logicals to Yes / No / Unknown {#223}", {
  expect_equal(pd_YesNo(c(TRUE, FALSE, NA)), c("Yes", "No", "Unknown"))
})

test_that("pd_DeathReason coalesces NA / blank / whitespace deathcls to Unknown {#221}", {
  df <- data.frame(
    deathcls = c("Adverse Event", NA, "", "  ", " AE "),
    stringsAsFactors = FALSE
  )
  expect_equal(
    pd_DeathReason(df),
    c("Adverse Event", "Unknown", "Unknown", "Unknown", "AE") # blanks -> Unknown, real value trimmed
  )
  # an entirely absent deathcls column is all Unknown
  expect_equal(pd_DeathReason(data.frame(x = 1:2)), c("Unknown", "Unknown"))
})

test_that("pd_CountryLabel coalesces NA / blank / whitespace country to Unknown {#221}", {
  expect_equal(
    pd_CountryLabel(c("USA", NA, "", "  ", " CAN ")),
    c("USA", "Unknown", "Unknown", "Unknown", "CAN")
  )
})
