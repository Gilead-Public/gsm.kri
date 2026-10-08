test_that("status rows sum to the participants under each dosed filter (#320)", {
  df <- ipc_classified()
  for (level in c("study", "country", "site")) {
    rows <- ipc_StatusRows(df, level)
    expect_equal(sum(rows$n[rows$Dosed == "all"]), 24)
    expect_equal(sum(rows$n[rows$Dosed == "Y"]), 12)
    expect_equal(sum(rows$n[rows$Dosed == "N"]), 11)
    expect_true(all(rows$n > 0))
    expect_true(all(rows$Level == level))
    expect_type(rows$GroupID, "character")
  }
})

test_that("only site rows carry their country (#320)", {
  df <- ipc_classified()
  site <- ipc_StatusRows(df, "site")
  expect_equal(unique(site$OuterGroupID[site$GroupID == "JP02"]), "Japan")
  expect_equal(unique(site$OuterGroupID[site$GroupID == "Unknown"]), "Unknown")
  expect_true(all(is.na(ipc_StatusRows(df, "country")$OuterGroupID)))
})

test_that("an unrecognised dosed flag appears under All only (#320)", {
  rows <- ipc_StatusRows(ipc_classified(), "study")
  unrecognized <- rows[rows$Status == "Unrecognized status", ]
  expect_equal(unrecognized$n[unrecognized$Dosed == "all"], 4)
  expect_equal(unrecognized$n[unrecognized$Dosed == "N"], 3)
  expect_false("Y" %in% unrecognized$Dosed)
})

test_that("the status spec stacks in vocabulary order as a 100% bar (#320)", {
  for (level in c("study", "country", "site")) {
    spec <- ipc_StatusBarSpec(level)
    expect_identical(names(spec$scales$fill$colors), names(ipc_StatusColors()))
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
  study <- ipc_StatusBarSpec("study")
  expect_equal(study$orientation, "horizontal")
  expect_null(study$zoom)
  expect_false(study$annotations$labels$segment$avoidCategoryOverlap)
  expect_equal(study$annotations$labels$segment$minSize, 80)
  for (level in c("country", "site")) {
    spec <- ipc_StatusBarSpec(level)
    expect_equal(spec$orientation, "vertical")
    expect_equal(spec$zoom, list(enabled = TRUE, mode = "x"))
  }
  expect_true(ipc_StatusBarSpec("site")$theme$dynamicCategoryAxis)
  expect_null(ipc_StatusBarSpec("country")$theme)
})
