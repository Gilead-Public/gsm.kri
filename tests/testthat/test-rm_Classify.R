test_that("rate rule flags participants at the 20% and 30% boundaries (#343)", {
  # D = 10 windows: 2 repeats = 20%, 3 repeats = 30%.
  lValues <- list(
    G = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
    A = c(1, 1, 1, 1, 3, 4, 5, 6, 7, 8, 9, 10),
    R = c(1, 1, 1, 1, 1, 4, 5, 6, 7, 8, 9, 10)
  )
  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), rm_metrics(), strFlagRule = "rate")
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(lClass$meta$thresholds, c(0.2, 0.3))
  expect_equal(df$Numerator, c(1, 2, 3))
  expect_equal(df$Denominator, c(10, 10, 10))
  expect_equal(as.character(df$flag), c("Green", "Amber", "Red"))
  expect_equal(df$rate, c(0.1, 0.2, 0.3))
})

test_that("the default count rule flags 2 repeating windows Amber and 3 Red (#343)", {
  # 1, 2 and 3 repeating windows, whatever the share of windows.
  lValues <- list(
    G = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8),
    A = c(1, 1, 1, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20),
    R = c(1, 1, 1, 1, 1)
  )
  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), rm_metrics())
  expect_equal(flag_of(lClass, "G"), "Green")
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(flag_of(lClass, "R"), "Red")
  expect_equal(lClass$meta$rule, "count")
  expect_equal(lClass$meta$thresholds, c(2, 3))
  expect_equal(lClass$meta$min_windows, 1)

  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), vFlagThresholds = c(1, 2))
  expect_equal(c(flag_of(lClass, "G"), flag_of(lClass, "A"), flag_of(lClass, "R")), c("Amber", "Red", "Red"))
})

test_that("rate thresholds come from the kri0020 metrics, or the argument (#343)", {
  lValues <- list(A = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
  lClass <- rm_Classify(
    rm_listings(rm_vs(lValues)),
    rm_metrics(strThreshold = "0.05,0.5"),
    strFlagRule = "rate"
  )
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(lClass$meta$thresholds, c(0.05, 0.5))

  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), strFlagRule = "rate")
  expect_equal(lClass$meta$thresholds, c(0.2, 0.3))
  expect_equal(flag_of(lClass, "A"), "Green")

  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), strFlagRule = "rate", vFlagThresholds = c(0, 0.1))
  expect_equal(flag_of(lClass, "A"), "Red")

  dfMetrics <- rm_metrics()
  dfMetrics$Threshold <- c("0.1,0.2", "0.2,0.3")
  dfMetrics$ID <- c("kri0020a", "kri0020b")
  expect_warning(rm_FlagThresholds("rate", dfMetrics = dfMetrics), "different thresholds")
})

test_that("participants with fewer windows than the minimum are Not evaluable (#343)", {
  lValues <- list(A = c(1, 1, 1), B = c(1, 1, 1, 1, 1))
  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), vFlagThresholds = c(1, 2), nMinWindows = 3)
  expect_equal(flag_of(lClass, "A"), "Not evaluable")
  expect_equal(flag_of(lClass, "B"), "Red")
  expect_equal(lClass$meta$min_windows, 3)
})

test_that("invalid flag settings are rejected (#343)", {
  dfL <- rm_listings(rm_vs(list(A = 1)))
  expect_error(rm_Classify(dfL, strFlagRule = "share"))
  expect_error(rm_Classify(dfL, vFlagThresholds = c(3, 2)), "Amber <= Red")
  expect_error(rm_Classify(dfL, vFlagThresholds = 2), "two non-negative")
  expect_error(rm_Classify(dfL, vFlagThresholds = c(-1, 2)), "two non-negative")
  expect_error(rm_Classify(dfL, nMinWindows = 0), "nMinWindows")
  expect_error(rm_Classify(dfL, nMinWindows = 1.5), "nMinWindows")
})

test_that("paired BP repeats only when systolic and diastolic BP both repeat (#343)", {
  dfVS <- rm_vs(list(A = c(120, 120, 120, 120, 120), B = c(110, 110, 110, NA, 110)), "sysbp")
  dfVS$diabp <- c(80, 80, 80, 81, 81, 70, 70, 70, 70, 70)
  lClass <- rm_Classify(rm_listings(dfVS))
  df <- lClass$participants[lClass$participants$vital %in% c("sysbp", "diabp", "bp"), ]
  # A: SBP repeats in 3 windows, DBP and the pair in 1. B: the missing SBP
  # leaves 4 paired records, and the pair repeats in both windows.
  expect_equal(df$Numerator[df$subjid == "A"], c(3, 1, 1))
  expect_equal(df$Numerator[df$subjid == "B"], c(2, 3, 2))
  expect_equal(df$Denominator[df$subjid == "B"], c(2, 3, 2))
  expect_true(all(is.na(df$metric[df$vital == "bp"])))
  expect_equal(flag_of(lClass, "A", "bp"), "Green")
  expect_equal(flag_of(lClass, "B", "bp"), "Amber")
  dfM <- lClass$measurements[lClass$measurements$vital == "bp", ]
  expect_equal(dfM$value_text[dfM$subjid == "A"], c("120/80", "120/80", "120/80", "120/81", "120/81"))
  expect_true(all(is.na(dfM$value)))
  expect_equal(lClass$vitals$vital, c("weight", "pulse", "sysbp", "diabp", "bp", "resp", "temp"))

  # Without both readings there is no paired BP.
  lClass <- rm_Classify(rm_listings(rm_vs(list(A = c(120, 120, 120)), "sysbp")))
  expect_false("bp" %in% lClass$participants$vital)
})

test_that("participants with D = 0 or no vitals are Not evaluable (#343)", {
  dfVS <- rm_vs(list(A = c(1, 1)))
  dfSubj <- data.frame(
    studyid = "S1", subjid = c("A", "B"), invid = "I1", country = "US"
  )
  lClass <- rm_Classify(rm_listings(dfVS, dfSubj))
  expect_equal(flag_of(lClass, "A"), "Not evaluable")
  expect_equal(flag_of(lClass, "B"), "Not evaluable")
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$n_records[df$subjid == "B"], 0)
  expect_true(is.na(df$rate[df$subjid == "A"]))
})

test_that("window length comes from the metrics and warns on a mismatch (#343)", {
  dfVS <- rm_vs(list(A = c(1, 1, 2, 2, 2)))
  lClass <- rm_Classify(rm_listings(dfVS), rm_metrics(nWindow = 2))
  expect_equal(lClass$meta$window_length, 2)
  expect_equal(lClass$meta$window_source, "metrics")
  expect_equal(lClass$participants$Numerator[1], 3)

  expect_warning(
    lClass <- rm_Classify(rm_listings(dfVS), rm_metrics(), nWindowLength = 4),
    "kri0020"
  )
  expect_equal(lClass$meta$window_length, 3)

  lClass <- rm_Classify(rm_listings(dfVS), nWindowLength = 4)
  expect_equal(lClass$meta$window_source, "argument")
  expect_equal(lClass$meta$window_length, 4)

  lClass <- rm_Classify(rm_listings(dfVS))
  expect_equal(lClass$meta$window_source, "default")
  expect_equal(lClass$meta$window_length, 3)
})

test_that("vitals without a KRI are windowed and flagged with the participant rule (#343)", {
  dfVS <- rm_vs(list(A = c(170, 170, 170)), "height")
  dfVS$weight <- c(1, 2, 3)
  dfVS$bsa <- c(2, 2, 2)
  lClass <- rm_Classify(rm_listings(dfVS))
  df <- lClass$participants
  vKRI <- rm_Vitals()$vital[!is.na(rm_Vitals()$metric)]
  expect_equal(df$vital, c(vKRI, "height", "bsa"))
  df <- df[df$vital %in% c("weight", "height", "bsa"), ]
  # Count rule: Amber at 2 repeating windows; weight never repeats.
  expect_equal(as.character(df$flag), c("Green", "Green", "Green"))
  expect_false("No KRI" %in% names(rm_FlagColors()))
  expect_equal(df$Numerator, c(0, 1, 1))
  expect_equal(df$metric, c("kri0020a", NA, NA))
  expect_true(all(lClass$measurements$in_repeat_window[lClass$measurements$vital == "height"]))
})

test_that("only enrolled participants are classified, with site and country from Mapped_SUBJ (#343)", {
  dfVS <- rm_vs(list(A = c(1, 1, 1), X = c(1, 1, 1)))
  dfVS$invid <- "stale"
  dfSubj <- data.frame(studyid = "S1", subjid = "A", invid = "I9", country = "FR")
  lClass <- rm_Classify(rm_listings(dfVS, dfSubj))
  expect_equal(unique(lClass$participants$subjid), "A")
  expect_equal(unique(lClass$measurements$subjid), "A")
  expect_equal(unique(lClass$measurements$invid), "I9")
  expect_equal(unique(lClass$participants$country), "FR")
})

test_that("an empty or missing Mapped_VS leaves every participant Not evaluable (#343)", {
  dfSubj <- data.frame(studyid = "S1", subjid = c("A", "B"), invid = "I1", country = "US")
  for (dfVS in list(NULL, rm_vs(list(A = 1))[0, ])) {
    lClass <- rm_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj))
    expect_equal(nrow(lClass$measurements), 0)
    expect_true(all(lClass$participants$flag == "Not evaluable"))
    expect_setequal(unique(lClass$participants$vital), rm_Vitals()$vital[!is.na(rm_Vitals()$metric)])
  }
})

test_that("rm_Classify() rejects a Mapped_SUBJ without site and country (#343)", {
  expect_error(
    rm_Classify(list(Mapped_SUBJ = data.frame(subjid = "A"))),
    "invid"
  )
})

test_that("site and country sums reconcile with all twelve repeat-measure workflows (#343)", {
  TestAtLogLevel()
  vSuffix <- c(weight = "a", pulse = "b", sysbp = "c", diabp = "d", resp = "e", temp = "f")
  vIDs <- c(paste0("kri0020", vSuffix), paste0("cou0020", vSuffix))
  lClass <- rm_Classify(list(
    Mapped_VS = mapped_data$Mapped_VS,
    Mapped_SUBJ = mapped_data$Mapped_SUBJ
  ))
  lResults <- workr::RunWorkflows(kri_workflow(vIDs), mapped_data)
  for (strVital in names(vSuffix)) {
    df <- lClass$participants[lClass$participants$vital == strVital, ]
    expect_gt(sum(df$Numerator), 0)
    for (strLevel in c("invid", "country")) {
      strID <- paste0(if (strLevel == "invid") "kri" else "cou", "0020", vSuffix[[strVital]])
      dfSum <- stats::aggregate(cbind(Numerator, Denominator) ~ GroupID,
        data = data.frame(GroupID = df[[strLevel]], Numerator = df$Numerator, Denominator = df$Denominator),
        FUN = sum
      )
      dfKRI <- lResults[[paste0("Analysis_", strID)]]$Analysis_Summary
      dfKRI <- dfKRI[match(dfSum$GroupID, dfKRI$GroupID), ]
      expect_equal(dfSum$Numerator, dfKRI$Numerator, label = strID)
      expect_equal(dfSum$Denominator, dfKRI$Denominator, label = strID)
    }
  }
})

test_that("Qual: participant N, D and flags match an independent derivation (#343)", {
  dfVS <- mapped_data$Mapped_VS
  dfSubj <- mapped_data$Mapped_SUBJ
  lClass <- rm_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj))
  lRate <- rm_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj), strFlagRule = "rate", nMinWindows = 2)

  # Pairwise definition of a repeat window, independent of run lengths.
  dfVS <- dfVS[dfVS$subjid %in% dfSubj$subjid, ]
  dfVS$bp <- ifelse(is.na(dfVS$sysbp) | is.na(dfVS$diabp), NA, paste(dfVS$sysbp, dfVS$diabp))
  for (strVital in c("weight", "pulse", "sysbp", "diabp", "bp", "resp", "temp")) {
    df <- dfVS[!is.na(dfVS[[strVital]]), ]
    df <- df[order(df$subjid, df$vs_dt, df$visit, method = "radix"), ]
    lSubj <- split(df[[strVital]], factor(df$subjid, levels = dfSubj$subjid))
    vN <- vapply(lSubj, function(x) {
      if (length(x) < 3) return(0)
      sum(vapply(seq_len(length(x) - 2), function(i) all(x[i:(i + 2)] == x[i]), logical(1)))
    }, numeric(1))
    vD <- vapply(lSubj, function(x) max(0, length(x) - 2), numeric(1))
    vRate <- vN / vD
    vFlag <- ifelse(vD == 0, "Not evaluable",
      ifelse(vN >= 3, "Red", ifelse(vN >= 2, "Amber", "Green"))
    )
    vRateFlag <- ifelse(vD < 2, "Not evaluable",
      ifelse(vRate >= 0.3, "Red", ifelse(vRate >= 0.2, "Amber", "Green"))
    )
    dfActual <- lClass$participants[lClass$participants$vital == strVital, ]
    dfActual <- dfActual[match(names(lSubj), dfActual$subjid), ]
    expect_equal(dfActual$Numerator, unname(vN), label = strVital)
    expect_equal(dfActual$Denominator, unname(vD), label = strVital)
    expect_equal(as.character(dfActual$flag), unname(vFlag), label = strVital)
    dfRate <- lRate$participants[lRate$participants$vital == strVital, ]
    dfRate <- dfRate[match(names(lSubj), dfRate$subjid), ]
    expect_equal(as.character(dfRate$flag), unname(vRateFlag), label = strVital)
  }
  expect_true(any(lClass$participants$flag == "Red"))
  expect_true(any(lRate$participants$flag == "Red"))
})

test_that("a missing country or site is labelled (missing) (#343)", {
  lListings <- rm_FixtureEdge()
  lListings$Mapped_SUBJ$invid[2] <- ""
  lClass <- rm_Classify(lListings)
  df <- unique(lClass$participants[c("subjid", "invid", "country")])
  expect_equal(df$country, c("(missing)", "X\" data-x=\"1 'q'"))
  expect_equal(df$invid, c("S4", "(missing)"))
  expect_equal(unique(lClass$measurements$country[lClass$measurements$subjid == "F"]), "(missing)")
})
