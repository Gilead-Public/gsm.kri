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

test_that("date ties keep input order deterministically (#307)", {
  df <- make_vs(c(5, 10, 10, 10))
  df$vs_dt <- as.Date("2024-01-01") + c(0, 0, 1, 2)
  # 5,10,10,10 has a run of 3; swapping the tied first pair breaks it.
  expect_equal(Detect_ConsecutiveRepeats(df, "weight")$Numerator, 1)
  expect_equal(
    Detect_ConsecutiveRepeats(df[c(2, 1, 3, 4), ], "weight")$Numerator,
    0
  )
})

test_that("records are sorted by date within subject (#307)", {
  df <- make_vs(c(10, 5, 10, 10))
  df$vs_dt <- as.Date("2024-01-01") + c(0, 3, 1, 2)
  expect_equal(Detect_ConsecutiveRepeats(df, "weight")$Numerator, 1)
})

test_that("nWindowLength is validated (#307)", {
  df <- make_vs(c(1, 1, 1))
  for (bad in list(1, 2.5, "3", c(2, 3), NA_real_)) {
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
    "must be character strings"
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

test_that("fixture date tie is resolved by input order (#307)", {
  dfS06 <- read_fixture("vs.csv")
  dfS06 <- dfS06[dfS06$subjid == "S06", ]
  expect_equal(Detect_ConsecutiveRepeats(dfS06, "weight")$Numerator, 1)
  # Swap V2 and V2U (same date).
  expect_equal(
    Detect_ConsecutiveRepeats(dfS06[c(1, 3, 2, 4, 5), ], "weight")$Numerator,
    0
  )
})
