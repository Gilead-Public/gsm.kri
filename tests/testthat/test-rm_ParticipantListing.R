test_that("tiles have one row per participant and KRI vital with Rate, N/D and Both labels (#347)", {
  lClass <- rm_Classify(rm_Fixture())
  dfTiles <- rm_ParticipantTiles(lClass)$tiles
  # Five participants x six KRI vitals; height has no KRI.
  expect_equal(nrow(dfTiles), 30)
  expect_false("height" %in% dfTiles$vital)
  a <- dfTiles[dfTiles$subjid == "D" & dfTiles$vital == "weight", ]
  expect_equal(a$flag, "Amber")
  expect_equal(c(a$label_rate, a$label_nd, a$label_both), c("25%", "1/4", "1/4\n25%"))
  ne <- dfTiles[dfTiles$subjid == "E" & dfTiles$vital == "weight", ]
  expect_equal(c(ne$label_rate, ne$label_nd, ne$label_both), c("NE", "NE", "NE"))
  expect_equal(c(ne$invid, ne$country), c("S3", "JP"))
})

test_that("tiles list participants worst flag first, then by most repeating windows (#347)", {
  dfTiles <- rm_ParticipantTiles(rm_Classify(rm_Fixture()))$tiles
  # A (Red, N = 2) before B (Red, N = 1), then D (Amber), then C and E (not evaluable).
  expect_equal(unique(dfTiles$subjid), c("A", "B", "D", "C", "E"))
  expect_equal(dfTiles$column[dfTiles$subjid == "A"], c("WT", "HR", "SBP", "DBP", "RR", "Temp"))
})

test_that("tile detail lists each measurement in order with its repeat-window status (#347)", {
  lClass <- rm_Classify(rm_Fixture())
  dfDetail <- rm_ParticipantTiles(lClass)$detail
  d <- dfDetail[dfDetail$subjid == "D" & dfDetail$column == "WT", ]
  expect_equal(d$seq, 1:6)
  expect_equal(d$value, c(90, 90, 90, 91, 92, 93))
  expect_equal(d$in_repeat_window, c("Yes", "Yes", "Yes", "No", "No", "No"))
  expect_equal(d$visit, paste0("V", 1:6))
  # Height has no tile, so no detail.
  expect_false(any(dfDetail$column == "Ht"))
})

test_that("tiles spec switches the cell label and pages 50 participants (#347)", {
  dfDetail <- rm_ParticipantTiles(rm_Classify(rm_Fixture()))$detail
  spec <- rm_ParticipantTilesSpec(dfDetail)
  expect_equal(spec$mapping, list(x = "column", y = "subjid", fill = "flag", label = "label_both"))
  expect_equal(rm_ParticipantTilesSpec(dfDetail, "nd")$mapping$label, "label_nd")
  expect_equal(rm_ParticipantTilesSpec(dfDetail, "rate")$mapping$label, "label_rate")
  expect_error(rm_ParticipantTilesSpec(dfDetail, "pct"))
  expect_equal(spec$rows$pageSize, 50)
  expect_identical(spec$expand$data, dfDetail)
  expect_equal(spec$expand$mapping$fill, "in_repeat_window")
  expect_setequal(names(spec$expand$scales$fill$colors), c("Yes", "No"))
})
