dfSubjects <- tibble::tibble(
  subjid = paste0("S", 1:4),
  studyid = "ST01",
  country = c("USA", "USA", "CAN", "CAN"),
  invid = c("INV-1", "INV-1", "INV-2", "INV-2")
)
dfDeath <- tibble::tibble(
  subjid = c("S1", "S2", "S4", "S5"),
  death_dy = c(20, 90, 120, NA)
)

test_that("pd_PrematureCohort keeps only deaths within the window {#223}", {
  # S1 @20 and S2 @90 are premature (boundary inclusive); S4 @120 is outside the
  # window and S5 has no death day.
  df <- pd_PrematureCohort(dfDeath, nWindowDays = 90)
  expect_equal(sort(df$subjid), c("S1", "S2"))
})

test_that("pd_PrematureCohort returns only death columns without dfSubjects {#223}", {
  df <- pd_PrematureCohort(dfDeath, nWindowDays = 90)
  expect_equal(names(df), names(dfDeath))
})

test_that("pd_PrematureCohort joins subject identity columns when supplied {#223}", {
  df <- pd_PrematureCohort(dfDeath, dfSubjects, nWindowDays = 90)
  expect_true(all(c("studyid", "country", "invid") %in% names(df)))
  expect_equal(df$country[df$subjid == "S1"], "USA")
  expect_equal(df$invid[df$subjid == "S2"], "INV-1")
})

test_that("pd_PrematureCohort tolerates missing identity columns {#223}", {
  # any_of drops absent columns rather than erroring.
  df <- pd_PrematureCohort(
    dfDeath,
    dplyr::select(dfSubjects, "subjid", "invid"),
    nWindowDays = 90
  )
  expect_true("invid" %in% names(df))
  expect_false("country" %in% names(df))
})
