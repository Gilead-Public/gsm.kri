test_that("tiles have one row per participant and vital with Rate, N/D and Both labels (#347)", {
  lClass <- rm_Classify(rm_Fixture(), strFlagRule = "rate")
  dfTiles <- rm_ParticipantTiles(lClass)
  # Five participants x (six KRI vitals + height); height is flagged too.
  expect_equal(nrow(dfTiles), 35)
  expect_equal(dfTiles$flag[dfTiles$subjid == "D" & dfTiles$vital == "height"], "Red")
  a <- dfTiles[dfTiles$subjid == "D" & dfTiles$vital == "weight", ]
  expect_equal(a$flag, "Amber")
  expect_equal(c(a$label_rate, a$label_nd, a$label_both), c("25%", "1/4", "1/4\n25%"))
  ne <- dfTiles[dfTiles$subjid == "E" & dfTiles$vital == "weight", ]
  expect_equal(c(ne$label_rate, ne$label_nd, ne$label_both), c("NE", "NE", "NE"))
  expect_equal(c(ne$invid, ne$country), c("S3", "JP"))
})

test_that("tiles list participants worst flag first, then by most repeating windows (#347)", {
  dfTiles <- rm_ParticipantTiles(rm_Classify(rm_Fixture(), strFlagRule = "rate"))
  # A (Red, N = 2) before B and D (Red, N = 1), then C and E (not evaluable).
  expect_equal(unique(dfTiles$subjid), c("A", "B", "D", "C", "E"))
  expect_equal(dfTiles$column[dfTiles$subjid == "A"], c("WT", "HR", "SBP", "DBP", "RR", "Temp", "Ht"))
})
