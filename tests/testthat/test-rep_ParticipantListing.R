test_that("tiles have one row per participant and vital with Rate, N/D and Both labels (#347)", {
  lClass <- rep_Classify(rep_Fixture(), strFlagRule = "rate")
  dfTiles <- rep_ParticipantTiles(lClass)
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
  dfTiles <- rep_ParticipantTiles(rep_Classify(rep_Fixture(), strFlagRule = "rate"))
  # A (Red, N = 2) before B and D (Red, N = 1), then C and E (not evaluable).
  expect_equal(unique(dfTiles$subjid), c("A", "B", "D", "C", "E"))
  expect_equal(dfTiles$column[dfTiles$subjid == "A"], c("WT", "HR", "SBP", "DBP", "RR", "Temp", "Ht"))
})

test_that("at the same worst flag more repeating windows come first, then participant (#347)", {
  lClass <- rep_Classify(rep_FixtureTies())
  expect_true(all(lClass$participants$flag[lClass$participants$vital == "weight"] == "Red"))
  expect_equal(rep_ParticipantOrder(lClass), c("B", "A", "C", "D", "E"))
  expect_equal(unique(rep_ParticipantTiles(lClass)$subjid), c("B", "A", "C", "D", "E"))
  expect_equal(unique(rep_DataTableWide(lClass)$subjid), c("B", "A", "C", "D", "E"))
})

test_that("tile rates round to whole percents and 0/0 is a missing rate, not NaN (#347)", {
  lClass <- rep_Classify(rep_listings(rep_vs(list(A = c(1, 1, 1, 2, 3), B = 1))), strFlagRule = "rate")
  df <- rep_ParticipantTiles(lClass)
  a <- df[df$subjid == "A" & df$vital == "weight", ]
  # A: 1 of 3 windows.
  expect_equal(c(a$label_rate, a$label_nd), c("33%", "1/3"))
  lClass <- rep_Classify(rep_listings(rep_vs(list(A = c(1, 1, 1, 1, 2)))), strFlagRule = "rate")
  a <- rep_ParticipantTiles(lClass)
  expect_equal(a$label_rate[a$vital == "weight"], "67%")
  b <- df[df$subjid == "B" & df$vital == "weight", ]
  expect_equal(c(b$Numerator, b$Denominator), c(0, 0))
  expect_identical(b$rate, NA_real_)
  expect_identical(lClass$participants$rate[lClass$participants$vital == "pulse"], NA_real_)
})
