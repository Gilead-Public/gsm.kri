test_that("pd_EligibilityStatus maps Source via the kri0014 rule {#250}", {
  out <- pd_EligibilityStatus(c(
    "Neither",
    "EDC I/E only",
    "Ineligible, Both Criteria",
    NA
  ))
  expect_equal(out, c("Eligible", "Ineligible", "Ineligible", "Unknown"))
})

test_that("pd_EligibilityStatus returns character(0) on empty input {#250}", {
  expect_equal(pd_EligibilityStatus(character(0)), character(0))
})
