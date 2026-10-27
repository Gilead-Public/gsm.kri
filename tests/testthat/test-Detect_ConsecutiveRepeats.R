make_vs <- function(values, subjid = "A") {
  data.frame(
    subjid = subjid,
    vs_dt = as.Date("2024-01-01") + seq_along(values) - 1,
    weight = values
  )
}

test_that("worked examples match the specification (#307)", {
  df <- rbind(
    make_vs(c(10, 10, 5, 3, 10), "A"),
    make_vs(c(10, 10, 10, 10, 10), "B"),
    make_vs(c(10, 10, 10, 1, 5, 6), "C")
  )
  res <- Detect_ConsecutiveRepeats(df, "weight")
  expect_equal(res$subjid, c("A", "B", "C"))
  expect_equal(res$Numerator, c(0, 3, 1))
  expect_equal(res$Denominator, c(3, 3, 4))
})

test_that("output composes with Input_Rate (#307)", {
  df <- rbind(
    make_vs(c(10, 10, 10, 10, 10), "A"),
    make_vs(c(10, 10, 10, 1, 5, 6), "B")
  )
  res <- Detect_ConsecutiveRepeats(df, "weight")
  input <- gsm.core::Input_Rate(
    dfSubjects = data.frame(subjid = c("A", "B"), invid = "I1"),
    dfNumerator = res,
    dfDenominator = res,
    strSubjectCol = "subjid",
    strGroupCol = "invid",
    strNumeratorMethod = "Sum",
    strDenominatorMethod = "Sum",
    strNumeratorCol = "Numerator",
    strDenominatorCol = "Denominator"
  )
  expect_equal(input$Metric, c(1, 0.25))
})

test_that("subjects with fewer than nWindowLength values get denominator 0 (#307)", {
  res <- Detect_ConsecutiveRepeats(make_vs(c(10, 10)), "weight")
  expect_equal(res$Numerator, 0)
  expect_equal(res$Denominator, 0)
})

test_that("missing values are excluded, not treated as non-matches (#307)", {
  res <- Detect_ConsecutiveRepeats(make_vs(c(10, NA, 10, 10)), "weight")
  expect_equal(res$Numerator, 1)
  expect_equal(res$Denominator, 1)
})

test_that("a subject with all values missing is kept with 0/0 (#307)", {
  df <- rbind(make_vs(c(NA, NA, NA), "A"), make_vs(c(1, 1, 1), "B"))
  res <- Detect_ConsecutiveRepeats(df, "weight")
  expect_equal(res$subjid, c("A", "B"))
  expect_equal(res$Numerator, c(0, 1))
  expect_equal(res$Denominator, c(0, 1))
})

test_that("strOrderCol breaks date ties independent of input order (#307)", {
  df <- make_vs(c(5, 10, 10, 10))
  df$vs_dt <- as.Date("2024-01-01") + c(0, 0, 1, 2)
  df$visit <- c("V1", "V2", "V3", "V4")
  # 5,10,10,10 has a run of 3; ordering V2 before V1 would break it.
  for (idx in list(1:4, c(2, 1, 3, 4), 4:1)) {
    expect_equal(
      Detect_ConsecutiveRepeats(df[idx, ], "weight", strOrderCol = "visit")$Numerator,
      1
    )
  }
  # Without a tie-breaker, ties fall back to input order.
  expect_equal(
    Detect_ConsecutiveRepeats(df[c(2, 1, 3, 4), ], "weight")$Numerator,
    0
  )
})

test_that("strOrderCol must name existing columns (#307)", {
  expect_error(
    Detect_ConsecutiveRepeats(make_vs(1:3), "weight", strOrderCol = "vs_tm"),
    "vs_tm"
  )
})

test_that("records are sorted by date within subject (#307)", {
  df <- make_vs(c(10, 5, 10, 10))
  df$vs_dt <- as.Date("2024-01-01") + c(0, 3, 1, 2)
  expect_equal(Detect_ConsecutiveRepeats(df, "weight")$Numerator, 1)
})

test_that("nWindowLength is validated (#307)", {
  df <- make_vs(c(1, 1, 1))
  for (bad in list(1, 2.5, "3", c(2, 3), NA_real_, Inf, -Inf, NaN)) {
    expect_error(
      Detect_ConsecutiveRepeats(df, "weight", nWindowLength = bad),
      "nWindowLength"
    )
  }
  expect_equal(
    Detect_ConsecutiveRepeats(df, "weight", nWindowLength = 2)$Numerator,
    2
  )
})

test_that("long-format data is filtered to the requested measure (#307)", {
  df <- data.frame(
    subjid = "A",
    vs_dt = rep(as.Date("2024-01-01") + 0:2, 2),
    measure = rep(c("pulse", "temp"), each = 3),
    value = c(70, 70, 70, 36, 37, 38)
  )
  pulse <- Detect_ConsecutiveRepeats(
    df, "value", strMeasureCol = "measure", strMeasureVal = "pulse"
  )
  temp <- Detect_ConsecutiveRepeats(
    df, "value", strMeasureCol = "measure", strMeasureVal = "temp"
  )
  expect_equal(pulse$Numerator, 1)
  expect_equal(temp$Numerator, 0)
  expect_error(
    Detect_ConsecutiveRepeats(df, "value", strMeasureCol = "measure"),
    "strMeasureVal"
  )
})

test_that("subjects are scored independently (#307)", {
  # A's tail and B's head would form a run of 3 if subjects bled together.
  df <- rbind(make_vs(c(1, 2, 7, 7), "A"), make_vs(c(7, 3, 4), "B"))
  res <- Detect_ConsecutiveRepeats(df, "weight")
  expect_equal(res$Numerator, c(0, 0))
})

test_that("missing columns give an informative error (#307)", {
  expect_error(
    Detect_ConsecutiveRepeats(make_vs(1:3), "pulse"),
    "pulse"
  )
})

test_that("non-data-frame df gives an informative error (#307)", {
  expect_error(
    Detect_ConsecutiveRepeats(list(weight = 1:3), "weight"),
    "must be a data frame"
  )
})

test_that("non-character column arguments give an informative error (#307)", {
  expect_error(
    Detect_ConsecutiveRepeats(
      make_vs(1:3), 3, strSubjectCol = 1, strDateCol = 2
    ),
    "must be a single non-missing character string"
  )
})

test_that("numeric column arguments are rejected even when mixed with character (#307)", {
  # A column named "3" must not let strValueCol = 3 pass and read column 3.
  df <- make_vs(c(1, 1, 1))
  df[["3"]] <- c(5, 6, 7)
  expect_error(
    Detect_ConsecutiveRepeats(df, 3),
    "strValueCol"
  )
  expect_error(
    Detect_ConsecutiveRepeats(df, "weight", strSubjectCol = 1),
    "strSubjectCol"
  )
  expect_error(
    Detect_ConsecutiveRepeats(df, c("weight", "3")),
    "strValueCol"
  )
  expect_error(
    Detect_ConsecutiveRepeats(df, NA_character_),
    "strValueCol"
  )
  expect_error(
    Detect_ConsecutiveRepeats(df, "weight", strOrderCol = 3),
    "strOrderCol"
  )
  expect_error(
    Detect_ConsecutiveRepeats(
      df, "weight", strMeasureCol = 3, strMeasureVal = "x"
    ),
    "strMeasureCol"
  )
})

test_that("subject-level results match the known-answer fixture (#307)", {
  dfVS <- read_fixture("vs.csv")
  dfExpected <- read_fixture("vs_expected_subject.csv")
  for (strMeasure in unique(dfExpected$measure)) {
    dfExp <- dfExpected[dfExpected$measure == strMeasure, ]
    res <- Detect_ConsecutiveRepeats(dfVS, strMeasure)
    res <- res[match(dfExp$subjid, res$subjid), ]
    expect_equal(res$Numerator, dfExp$Numerator, label = strMeasure)
    expect_equal(res$Denominator, dfExp$Denominator, label = strMeasure)
  }
})

test_that("fixture date tie is resolved by visit, not input order (#307)", {
  dfS06 <- read_fixture("vs.csv")
  dfS06 <- dfS06[dfS06$subjid == "S06", ]
  # V2 and V2U share a date; swapping them must not change the result.
  for (idx in list(1:5, c(1, 3, 2, 4, 5), 5:1)) {
    expect_equal(
      Detect_ConsecutiveRepeats(dfS06[idx, ], "weight", strOrderCol = "visit")$Numerator,
      1
    )
  }
})
