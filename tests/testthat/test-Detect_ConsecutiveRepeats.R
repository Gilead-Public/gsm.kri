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
      Detect_ConsecutiveRepeats(
        df[idx, ],
        "weight",
        strOrderCol = "visit"
      )$Numerator,
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
    df,
    "value",
    strMeasureCol = "measure",
    strMeasureVal = "pulse"
  )
  temp <- Detect_ConsecutiveRepeats(
    df,
    "value",
    strMeasureCol = "measure",
    strMeasureVal = "temp"
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
      make_vs(1:3),
      3,
      strSubjectCol = 1,
      strDateCol = 2
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
      df,
      "weight",
      strMeasureCol = 3,
      strMeasureVal = "x"
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
      Detect_ConsecutiveRepeats(
        dfS06[idx, ],
        "weight",
        strOrderCol = "visit"
      )$Numerator,
      1
    )
  }
})

# MarkConsecutiveRepeats(): the shared windowing engine (#342)

test_that("worked examples mark every value inside a repeat window (#342)", {
  df <- rbind(
    make_vs(c(10, 10, 5, 3, 10), "A"),
    make_vs(c(10, 10, 10, 10, 10), "B"),
    make_vs(c(10, 10, 10, 1, 5, 6), "C")
  )
  res <- MarkConsecutiveRepeats(df, "weight")
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
  res <- MarkConsecutiveRepeats(df, "weight", strOrderCol = "visit")
  expect_equal(res$visit, c("V1", "V2a", "V2b", "V3"))
  expect_equal(res$extra, c("a", "b", "d", "c"))
  expect_equal(res$in_repeat_window, c(FALSE, FALSE, FALSE, FALSE))
})

test_that("missing values are dropped before windows are formed (#342)", {
  res <- MarkConsecutiveRepeats(make_vs(c(10, NA, 10, 10)), "weight")
  expect_equal(nrow(res), 3)
  expect_equal(res$seq, 1:3)
  expect_true(all(res$in_repeat_window))
  expect_equal(res$window_start, c(TRUE, FALSE, FALSE))
})

test_that("a single record or fewer than W records is never marked (#342)", {
  expect_false(MarkConsecutiveRepeats(make_vs(7), "weight")$in_repeat_window)
  res <- MarkConsecutiveRepeats(make_vs(c(7, 7)), "weight")
  expect_equal(res$in_repeat_window, c(FALSE, FALSE))
})

test_that("window length 2 and 4 change the marking (#342)", {
  df <- make_vs(c(1, 1, 2, 3, 3, 3))
  res2 <- MarkConsecutiveRepeats(df, "weight", nWindowLength = 2)
  expect_equal(res2$in_repeat_window, c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
  expect_equal(res2$window_start, c(TRUE, FALSE, FALSE, TRUE, TRUE, FALSE))
  res4 <- MarkConsecutiveRepeats(df, "weight", nWindowLength = 4)
  expect_false(any(res4$in_repeat_window))
})

test_that("overlapping windows each start once (#342)", {
  res <- MarkConsecutiveRepeats(make_vs(rep(4, 6)), "weight")
  expect_equal(res$window_start, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_true(all(res$in_repeat_window))
})

test_that("a run never continues across subjects (#342)", {
  df <- rbind(make_vs(c(1, 1), "A"), make_vs(c(1, 1), "B"))
  res <- MarkConsecutiveRepeats(df, "weight")
  expect_false(any(res$in_repeat_window))
})

test_that("arguments are validated by the engine (#342)", {
  df <- make_vs(c(1, 1, 1))
  expect_error(MarkConsecutiveRepeats(df, "weight", nWindowLength = 1), "nWindowLength")
  expect_error(MarkConsecutiveRepeats(df, "pulse"), "not found")
  expect_error(MarkConsecutiveRepeats(list(), "weight"), "data frame")
})

test_that("empty input returns an empty frame with the marking columns (#342)", {
  res <- MarkConsecutiveRepeats(make_vs(1)[0, ], "weight")
  expect_equal(nrow(res), 0)
  expect_true(all(c("seq", "in_repeat_window", "window_start") %in% names(res)))
})

test_that("Detect_ConsecutiveRepeats() counts equal the marked window starts for all six vitals (#342)", {
  dfVS <- mapped_data$Mapped_VS
  expect_gt(nrow(dfVS), 0)
  for (strCol in c("weight", "pulse", "sysbp", "diabp", "resp", "temp")) {
    dfDetect <- Detect_ConsecutiveRepeats(dfVS, strCol, strOrderCol = "visit")
    dfMark <- MarkConsecutiveRepeats(dfVS, strCol, strOrderCol = "visit")
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
  res <- MarkConsecutiveRepeats(
    df, "value",
    strMeasureCol = "test", strMeasureVal = "WT"
  )
  expect_equal(res$test, rep("WT", 3))
  expect_true(all(res$in_repeat_window))
})

test_that("records with a missing subject are dropped with a warning, not a crash", {
  df <- rbind(
    make_vs(c(1, 1, 1), "A"),
    make_vs(c(2, 2, 2, 2), NA),
    make_vs(c(1, 2, 3), "B")
  )
  expect_warning(
    res <- Detect_ConsecutiveRepeats(df, "weight"),
    "Dropped 4 records with a missing"
  )
  expect_equal(res$subjid, c("A", "B"))
  expect_equal(res$Numerator, c(1, 0))
  expect_equal(res$Denominator, c(1, 1))
  expect_false(anyNA(MarkConsecutiveRepeats(df, "weight")$subjid))
})

test_that("empty input returns an empty summary with the expected columns", {
  res <- Detect_ConsecutiveRepeats(make_vs(1)[0, ], "weight")
  expect_equal(names(res), c("subjid", "Numerator", "Denominator"))
  expect_equal(nrow(res), 0)
})

test_that("input columns that the engine writes are rejected (#342)", {
  for (strCol in c("seq", "in_repeat_window", "window_start")) {
    df <- make_vs(c(1, 1, 1))
    df[[strCol]] <- 1:3
    expect_error(Detect_ConsecutiveRepeats(df, strCol), "reserved", label = strCol)
    expect_error(
      Detect_ConsecutiveRepeats(df, "weight", strOrderCol = strCol),
      "reserved",
      label = strCol
    )
  }
  df <- data.frame(seq = "A", window_start = Sys.Date() + 0:2, weight = 1)
  expect_error(
    Detect_ConsecutiveRepeats(df, "weight", strSubjectCol = "seq", strDateCol = "window_start"),
    "are reserved"
  )
  # A reserved name that is not one of the named columns is overwritten, not used.
  df <- make_vs(c(1, 1, 1))
  df$seq <- 9
  expect_equal(MarkConsecutiveRepeats(df, "weight")$seq, 1:3)
})

test_that("results are identical to the v1.8.0 implementation on the six vitals (#342)", {
  dfVS <- mapped_data$Mapped_VS
  dfVS <- dfVS[!is.na(dfVS$subjid), ]
  for (strCol in c("weight", "pulse", "sysbp", "diabp", "resp", "temp")) {
    for (nW in 2:4) {
      expect_identical(
        Detect_ConsecutiveRepeats(dfVS, strCol, strOrderCol = "visit", nWindowLength = nW),
        Detect_ConsecutiveRepeats_v1.8.0(dfVS, strCol, strOrderCol = "visit", nWindowLength = nW),
        label = paste(strCol, nW)
      )
    }
  }
})

test_that("results are identical to the v1.8.0 implementation on random data (#342)", {
  withr::local_seed(20240307)
  for (i in seq_len(300)) {
    df <- detect_random_vs(
      nSubjects = sample(0:8, 1),
      nValues = sample(1:4, 1),
      pNA = sample(c(0, 0.15, 0.5), 1)
    )
    if (i %% 3 == 0) {
      # Paired-BP-like text values.
      df$value <- ifelse(is.na(df$value), NA_character_, paste0(df$value, "/80"))
    }
    nW <- sample(2:5, 1)
    strOrderCol <- if (i %% 2 == 0) "visit"
    label <- paste0("run ", i, ", W = ", nW)
    expect_identical(
      Detect_ConsecutiveRepeats(df, "value", strOrderCol = strOrderCol, nWindowLength = nW),
      Detect_ConsecutiveRepeats_v1.8.0(df, "value", strOrderCol = strOrderCol, nWindowLength = nW),
      label = label
    )
    expect_identical(
      Detect_ConsecutiveRepeats(
        df, "value",
        strMeasureCol = "measure", strMeasureVal = "HR", nWindowLength = nW
      ),
      Detect_ConsecutiveRepeats_v1.8.0(
        df, "value",
        strMeasureCol = "measure", strMeasureVal = "HR", nWindowLength = nW
      ),
      label = paste(label, "(long)")
    )
  }
})
