# Helper: single subject with evenly spaced visits and the supplied values.
MakeSubject <- function(vValues, strSubject = "S1") {
  data.frame(
    subjid = rep(strSubject, length(vValues)),
    vs_dt = as.Date("2024-01-01") + seq(0, by = 30, length.out = length(vValues)),
    weight = vValues,
    stringsAsFactors = FALSE
  )
}

Totals <- function(df) {
  c(
    Numerator = sum(df$IsRepeatWindow),
    Denominator = sum(df$IsEvaluableWindow)
  )
}

# ---- Worked examples from gsm.roadmap#84 (W = 3) ----------------------------

test_that("non-consecutive repeats do not count", {
  # 10, 10, 5, 3, 10 -> 0 / 3. Under the superseded record-level rule this scored 3/5.
  dfWindows <- Count_Duplicates(MakeSubject(c(10, 10, 5, 3, 10)), strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 0, Denominator = 3))
})

test_that("a fully repeated series scores 100%", {
  dfWindows <- Count_Duplicates(MakeSubject(rep(10, 5)), strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 3, Denominator = 3))
})

test_that("a single run of W is counted once", {
  # 10, 10, 10, 1, 5, 6 -> 1 / 4
  dfWindows <- Count_Duplicates(MakeSubject(c(10, 10, 10, 1, 5, 6)), strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 1, Denominator = 4))
})

# ---- Window mechanics -------------------------------------------------------

test_that("windows are attributed to the record where they end", {
  dfWindows <- Count_Duplicates(MakeSubject(c(10, 10, 10, 10)), strValueCol = "weight")

  # First W - 1 records close no window.
  expect_equal(dfWindows$IsEvaluableWindow, c(0L, 0L, 1L, 1L))
  expect_equal(dfWindows$IsRepeatWindow, c(0L, 0L, 1L, 1L))
})

test_that("a run of length L yields L - W + 1 repeat windows", {
  for (nRun in 3:6) {
    dfWindows <- Count_Duplicates(
      MakeSubject(c(1, 2, rep(9, nRun), 3, 4)),
      strValueCol = "weight"
    )
    expect_equal(sum(dfWindows$IsRepeatWindow), nRun - 3 + 1)
  }
})

test_that("nWindowLength changes the rule", {
  vValues <- c(10, 10, 5, 5, 5, 5)

  # W = 2 catches the leading pair; W = 4 only the trailing quartet.
  expect_equal(
    Totals(Count_Duplicates(MakeSubject(vValues), strValueCol = "weight", nWindowLength = 2)),
    c(Numerator = 4, Denominator = 5)
  )
  expect_equal(
    Totals(Count_Duplicates(MakeSubject(vValues), strValueCol = "weight", nWindowLength = 4)),
    c(Numerator = 1, Denominator = 3)
  )
})

test_that("window length is read from character metric metadata", {
  # Metric YAML meta values may arrive as character.
  expect_equal(
    Totals(Count_Duplicates(MakeSubject(rep(10, 5)), strValueCol = "weight", nWindowLength = "3")),
    Totals(Count_Duplicates(MakeSubject(rep(10, 5)), strValueCol = "weight", nWindowLength = 3))
  )
})

test_that("invalid window lengths are rejected", {
  df <- MakeSubject(rep(10, 5))

  expect_error(Count_Duplicates(df, strValueCol = "weight", nWindowLength = 1))
  expect_error(Count_Duplicates(df, strValueCol = "weight", nWindowLength = 2.5))
  expect_error(Count_Duplicates(df, strValueCol = "weight", nWindowLength = "three"))
  expect_error(Count_Duplicates(df, strValueCol = "weight", nWindowLength = c(2, 3)))
})

# ---- Edge cases from the requirement ---------------------------------------

test_that("subjects with fewer than W measurements are excluded, not scored zero", {
  dfWindows <- Count_Duplicates(MakeSubject(c(10, 10)), strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 0, Denominator = 0))
  expect_equal(nrow(dfWindows), 2)
})

test_that("missing values are dropped rather than breaking a run", {
  # 10, NA, 10, 10 collapses to 10, 10, 10 -> one repeat window.
  dfWindows <- Count_Duplicates(MakeSubject(c(10, NA, 10, 10)), strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 1, Denominator = 1))
  expect_equal(nrow(dfWindows), 3)
})

test_that("subjects are windowed independently", {
  df <- rbind(
    MakeSubject(rep(10, 4), "S1"),
    MakeSubject(c(1, 2, 3, 4), "S2")
  )
  dfWindows <- Count_Duplicates(df, strValueCol = "weight")

  expect_equal(Totals(dfWindows), c(Numerator = 2, Denominator = 4))
  # The S1 -> S2 boundary is not itself a window.
  expect_equal(sum(dfWindows$IsRepeatWindow[dfWindows$subjid == "S2"]), 0)
})

test_that("records are ordered by date before windowing", {
  df <- MakeSubject(c(10, 5, 10, 10))
  # Reorder so the identical values are only adjacent once sorted by date.
  df$weight <- c(10, 10, 5, 10)
  df$vs_dt <- as.Date(c("2024-01-01", "2024-04-01", "2024-02-01", "2024-03-01"))

  dfWindows <- Count_Duplicates(df, strValueCol = "weight")

  expect_equal(dfWindows$weight, c(10, 5, 10, 10))
  expect_equal(Totals(dfWindows), c(Numerator = 0, Denominator = 2))
})

test_that("tied dates keep input order", {
  df <- MakeSubject(c(10, 10, 10))
  df$vs_dt <- as.Date("2024-01-01")
  df$weight <- c(1, 2, 3)

  dfWindows <- Count_Duplicates(df, strValueCol = "weight")

  expect_equal(dfWindows$weight, c(1, 2, 3))
})

test_that("an empty input returns the window columns", {
  dfWindows <- Count_Duplicates(MakeSubject(numeric(0)), strValueCol = "weight")

  expect_equal(nrow(dfWindows), 0)
  expect_true(all(
    c("RunID", "RunLength", "IsRepeatRun", "IsEvaluableWindow", "IsRepeatWindow") %in%
      names(dfWindows)
  ))
})

# ---- Long format (labs) -----------------------------------------------------

test_that("long-format data is filtered to the requested measure", {
  df_lb <- data.frame(
    subjid = rep("S1", 8),
    lb_dt = rep(as.Date("2024-01-01") + seq(0, 90, by = 30), each = 2),
    lbtstnam = rep(c("ALT", "AST"), 4),
    rptresn = c(25, 30, 25, 31, 25, 32, 40, 33),
    stringsAsFactors = FALSE
  )

  dfALT <- Count_Duplicates(
    df_lb,
    strDateCol = "lb_dt", strValueCol = "rptresn",
    strMeasureCol = "lbtstnam", strMeasureVal = "ALT"
  )

  expect_equal(nrow(dfALT), 4)
  # ALT: 25, 25, 25, 40 -> 1 / 2
  expect_equal(Totals(dfALT), c(Numerator = 1, Denominator = 2))
})

# ---- Report-facing columns --------------------------------------------------

test_that("IsRepeatRun marks every record in a qualifying run", {
  dfWindows <- Detect_ConsecutiveRepeats(
    MakeSubject(c(1, 9, 9, 9, 2, 7, 7)),
    strValueCol = "weight"
  )

  expect_equal(dfWindows$IsRepeatRun, c(0L, 1L, 1L, 1L, 0L, 0L, 0L))
  expect_equal(dfWindows$RunLength, c(1L, 3L, 3L, 3L, 1L, 2L, 2L))
  expect_equal(dfWindows$RunID, c(1L, 2L, 2L, 2L, 3L, 4L, 4L))
})

test_that("run highlighting reconciles with the metric numerator", {
  # Every repeat window sits inside a highlighted run, and each run of length L
  # contributes L - W + 1 windows.
  dfWindows <- Detect_ConsecutiveRepeats(
    MakeSubject(c(1, 9, 9, 9, 9, 2, 7, 7)),
    strValueCol = "weight"
  )

  expect_true(all(dfWindows$IsRepeatRun[dfWindows$IsRepeatWindow == 1] == 1L))

  nExpected <- sum(vapply(
    split(dfWindows$RunLength, dfWindows$RunID),
    function(x) max(0, x[1] - 3 + 1),
    numeric(1)
  ))
  expect_equal(sum(dfWindows$IsRepeatWindow), nExpected)
})

# ---- Input validation -------------------------------------------------------

test_that("missing required columns error", {
  df <- MakeSubject(rep(10, 4))

  expect_error(Count_Duplicates(df, strValueCol = "nope"))
  expect_error(Count_Duplicates(df, strSubjectCol = "nope", strValueCol = "weight"))
  expect_error(Count_Duplicates(df, strDateCol = "nope", strValueCol = "weight"))
  expect_error(Count_Duplicates("not a data frame", strValueCol = "weight"))
})
