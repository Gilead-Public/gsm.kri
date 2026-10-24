make_vs <- function(values, subjid = "A") {
  data.frame(
    subjid = subjid,
    vs_dt = as.Date("2024-01-01") + seq_along(values) - 1,
    weight = values
  )
}

test_that("worked examples mark every value inside a repeat window (#342)", {
  df <- rbind(
    make_vs(c(10, 10, 5, 3, 10), "A"),
    make_vs(c(10, 10, 10, 10, 10), "B"),
    make_vs(c(10, 10, 10, 1, 5, 6), "C")
  )
  res <- Mark_ConsecutiveRepeats(df, "weight")
  expect_equal(res$subjid, rep(c("A", "B", "C"), c(5, 5, 6)))
  expect_equal(res$seq, c(1:5, 1:5, 1:6))
  expect_equal(
    res$in_repeat_window,
    c(rep(FALSE, 5), rep(TRUE, 5), TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    res$window_start,
    c(rep(FALSE, 5), TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, rep(FALSE, 5))
  )
})

test_that("rows come back in evaluation order with input columns kept (#342)", {
  df <- data.frame(
    subjid = c("A", "A", "A", "A"),
    vs_dt = as.Date("2024-01-01") + c(2, 0, 1, 1),
    visit = c("V3", "V1", "V2b", "V2a"),
    weight = c(5, 5, 5, 6),
    extra = c("c", "a", "d", "b")
  )
  res <- Mark_ConsecutiveRepeats(df, "weight", strOrderCol = "visit")
  expect_equal(res$visit, c("V1", "V2a", "V2b", "V3"))
  expect_equal(res$extra, c("a", "b", "d", "c"))
  expect_equal(res$in_repeat_window, c(FALSE, FALSE, FALSE, FALSE))
})

test_that("missing values are dropped before windows are formed (#342)", {
  res <- Mark_ConsecutiveRepeats(make_vs(c(10, NA, 10, 10)), "weight")
  expect_equal(nrow(res), 3)
  expect_equal(res$seq, 1:3)
  expect_true(all(res$in_repeat_window))
  expect_equal(res$window_start, c(TRUE, FALSE, FALSE))
})

test_that("a single record or fewer than W records is never marked (#342)", {
  expect_false(Mark_ConsecutiveRepeats(make_vs(7), "weight")$in_repeat_window)
  res <- Mark_ConsecutiveRepeats(make_vs(c(7, 7)), "weight")
  expect_equal(res$in_repeat_window, c(FALSE, FALSE))
})

test_that("window length 2 and 4 change the marking (#342)", {
  df <- make_vs(c(1, 1, 2, 3, 3, 3))
  res2 <- Mark_ConsecutiveRepeats(df, "weight", nWindowLength = 2)
  expect_equal(res2$in_repeat_window, c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
  expect_equal(res2$window_start, c(TRUE, FALSE, FALSE, TRUE, TRUE, FALSE))
  res4 <- Mark_ConsecutiveRepeats(df, "weight", nWindowLength = 4)
  expect_false(any(res4$in_repeat_window))
})

test_that("overlapping windows each start once (#342)", {
  res <- Mark_ConsecutiveRepeats(make_vs(rep(4, 6)), "weight")
  expect_equal(res$window_start, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_true(all(res$in_repeat_window))
})

test_that("a run never continues across subjects (#342)", {
  df <- rbind(make_vs(c(1, 1), "A"), make_vs(c(1, 1), "B"))
  res <- Mark_ConsecutiveRepeats(df, "weight")
  expect_false(any(res$in_repeat_window))
})

test_that("arguments are validated as in Detect_ConsecutiveRepeats() (#342)", {
  df <- make_vs(c(1, 1, 1))
  expect_error(Mark_ConsecutiveRepeats(df, "weight", nWindowLength = 1), "nWindowLength")
  expect_error(Mark_ConsecutiveRepeats(df, "pulse"), "not found")
  expect_error(Mark_ConsecutiveRepeats(list(), "weight"), "data frame")
})

test_that("empty input returns an empty frame with the marking columns (#342)", {
  res <- Mark_ConsecutiveRepeats(make_vs(1)[0, ], "weight")
  expect_equal(nrow(res), 0)
  expect_true(all(c("seq", "in_repeat_window", "window_start") %in% names(res)))
})

test_that("Detect_ConsecutiveRepeats() counts equal the marked window starts for all six vitals (#342)", {
  dfVS <- mapped_data$Mapped_VS
  expect_gt(nrow(dfVS), 0)
  for (strCol in c("weight", "pulse", "sysbp", "diabp", "resp", "temp")) {
    dfDetect <- Detect_ConsecutiveRepeats(dfVS, strCol, strOrderCol = "visit")
    dfMark <- Mark_ConsecutiveRepeats(dfVS, strCol, strOrderCol = "visit")
    vN <- tapply(dfMark$window_start, factor(dfMark$subjid, dfDetect$subjid), sum)
    vN[is.na(vN)] <- 0
    expect_equal(unname(as.numeric(vN)), dfDetect$Numerator, label = strCol)
    vMeasured <- table(factor(dfMark$subjid, dfDetect$subjid))
    expect_equal(
      pmax(0, as.numeric(vMeasured) - 2),
      dfDetect$Denominator,
      label = strCol
    )
    expect_gt(sum(dfMark$in_repeat_window), 0)
  }
})

test_that("measure filtering applies to long data (#342)", {
  df <- data.frame(
    subjid = "A",
    vs_dt = as.Date("2024-01-01") + rep(0:2, 2),
    test = rep(c("WT", "HR"), each = 3),
    value = c(1, 1, 1, 60, 70, 80)
  )
  res <- Mark_ConsecutiveRepeats(
    df, "value",
    strMeasureCol = "test", strMeasureVal = "WT"
  )
  expect_equal(res$test, rep("WT", 3))
  expect_true(all(res$in_repeat_window))
})
