test_that("status rows sum to the participants under each dosed filter (#320, #332)", {
  df <- ipm_classified()
  for (level in c("study", "country", "site")) {
    rows <- ipm_StatusRows(df, level)
    expect_equal(sum(rows$n[rows$Dosed == "all"]), 29)
    expect_equal(sum(rows$n[rows$Dosed == "Y"]), 17)
    expect_equal(sum(rows$n[rows$Dosed == "N"]), 11)
    expect_true(all(rows$n > 0))
    expect_true(all(rows$Level == level))
    expect_type(rows$GroupID, "character")
  }
})

test_that("only site rows carry their country (#320)", {
  df <- ipm_classified()
  site <- ipm_StatusRows(df, "site")
  expect_equal(unique(site$OuterGroupID[site$GroupID == "JP02"]), "Japan")
  expect_equal(unique(site$OuterGroupID[site$GroupID == "Unknown"]), "Unknown")
  expect_true(all(is.na(ipm_StatusRows(df, "country")$OuterGroupID)))
})

test_that("an unrecognised dosed flag appears under All only; an unrecognised outcome under Dosed (#320, #332)", {
  rows <- ipm_StatusRows(ipm_classified(), "study")
  unrecognized <- rows[rows$Status == "Unrecognized status", ]
  # P15's dosed flag is unrecognised; P29 is dosed with an unrecognised outcome.
  expect_equal(unrecognized$n[unrecognized$Dosed == "all"], 5)
  expect_equal(unrecognized$n[unrecognized$Dosed == "N"], 3)
  expect_equal(unrecognized$n[unrecognized$Dosed == "Y"], 1)
})

test_that("the status spec stacks in vocabulary order as a 100% bar (#320)", {
  for (level in c("study", "country", "site")) {
    spec <- ipm_StatusBarSpec(level)
    expect_identical(names(spec$scales$fill$colors), names(ipm_StatusColors()))
    expect_null(spec$stat)
    expect_equal(spec$position, "fill")
    expect_equal(spec$mapping, list(x = "GroupID", y = "n", fill = "Status"))
    expect_equal(spec$scales$fill$label, "")
    expect_equal(spec$scales$y$label, "Participants")
    expect_equal(spec$labels$title, "Participants by status")
    expect_s3_class(spec$annotations$labels$segment$formatter, "JS_EVAL")
    expect_s3_class(spec$tooltip$formatter, "JS_EVAL")
  }
})

test_that("the study bar is horizontal; country and site zoom (#320)", {
  study <- ipm_StatusBarSpec("study")
  expect_equal(study$orientation, "horizontal")
  expect_null(study$zoom)
  expect_false(study$annotations$labels$segment$avoidCategoryOverlap)
  expect_equal(study$annotations$labels$segment$minSize, 80)
  for (level in c("country", "site")) {
    spec <- ipm_StatusBarSpec(level)
    expect_equal(spec$orientation, "vertical")
    expect_equal(spec$zoom, list(enabled = TRUE, mode = "x"))
  }
  expect_true(ipm_StatusBarSpec("site")$theme$dynamicCategoryAxis)
  expect_null(ipm_StatusBarSpec("country")$theme)
})
