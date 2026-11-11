test_that("rate rule flags participants at the 20% and 30% boundaries (#343)", {
  # D = 10 windows: 2 repeats = 20%, 3 repeats = 30%.
  lValues <- list(
    G = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
    A = c(1, 1, 1, 1, 3, 4, 5, 6, 7, 8, 9, 10),
    R = c(1, 1, 1, 1, 1, 4, 5, 6, 7, 8, 9, 10)
  )
  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), rep_metrics(), strFlagRule = "rate")
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
  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), rep_metrics())
  expect_equal(flag_of(lClass, "G"), "Green")
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(flag_of(lClass, "R"), "Red")
  expect_equal(lClass$meta$rule, "count")
  expect_equal(lClass$meta$thresholds, c(2, 3))
  expect_equal(lClass$meta$min_windows, 1)

  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), vFlagThresholds = c(1, 2))
  expect_equal(c(flag_of(lClass, "G"), flag_of(lClass, "A"), flag_of(lClass, "R")), c("Amber", "Red", "Red"))
})

test_that("rate thresholds come from the kri0020 metrics, or the argument (#343)", {
  lValues <- list(A = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
  lClass <- rep_Classify(
    rep_listings(rep_vs(lValues)),
    rep_metrics(strThreshold = "0.05,0.5"),
    strFlagRule = "rate"
  )
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(lClass$meta$thresholds, c(0.05, 0.5))

  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), strFlagRule = "rate")
  expect_equal(lClass$meta$thresholds, c(0.2, 0.3))
  expect_equal(flag_of(lClass, "A"), "Green")

  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), strFlagRule = "rate", vFlagThresholds = c(0.05, 0.1))
  expect_equal(flag_of(lClass, "A"), "Red")

  dfMetrics <- rep_metrics()
  dfMetrics$Threshold <- c("0.1,0.2", "0.2,0.3")
  dfMetrics$ID <- c("kri0020a", "kri0020b")
  expect_warning(rep_FlagThresholds("rate", dfMetrics = dfMetrics), "different Threshold values")
})

test_that("participants with fewer windows than the minimum are Not evaluable (#343)", {
  lValues <- list(A = c(1, 1, 1), B = c(1, 1, 1, 1, 1))
  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), vFlagThresholds = c(1, 2), nMinWindows = 3)
  expect_equal(flag_of(lClass, "A"), "Not evaluable")
  expect_equal(flag_of(lClass, "B"), "Red")
  expect_equal(lClass$meta$min_windows, 3)
})

test_that("invalid flag settings are rejected (#343)", {
  dfL <- rep_listings(rep_vs(list(A = 1)))
  expect_error(rep_Classify(dfL, strFlagRule = "share"))
  expect_error(rep_Classify(dfL, vFlagThresholds = c(3, 2)), "Amber <= Red")
  expect_error(rep_Classify(dfL, vFlagThresholds = 2), "two positive")
  expect_error(rep_Classify(dfL, vFlagThresholds = c(-1, 2)), "two positive")
  # 0 would flag participants without a repeating window, under either rule.
  expect_error(rep_Classify(dfL, vFlagThresholds = c(0, 0)), "two positive")
  expect_error(rep_Classify(dfL, strFlagRule = "rate", vFlagThresholds = c(0, 0)), "two positive")
  expect_error(rep_Classify(dfL, vFlagThresholds = c(0, 1)), "two positive")
  expect_error(rep_Classify(dfL, nMinWindows = 0), "nMinWindows")
  expect_error(rep_Classify(dfL, nMinWindows = 1.5), "nMinWindows")
})

test_that("paired BP repeats only when systolic and diastolic BP both repeat (#343)", {
  dfVS <- rep_vs(list(A = c(120, 120, 120, 120, 120), B = c(110, 110, 110, NA, 110)), "sysbp")
  dfVS$diabp <- c(80, 80, 80, 81, 81, 70, 70, 70, 70, 70)
  lClass <- rep_Classify(rep_listings(dfVS))
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
  lClass <- rep_Classify(rep_listings(rep_vs(list(A = c(120, 120, 120)), "sysbp")))
  expect_false("bp" %in% lClass$participants$vital)
})

test_that("participants with D = 0 or no vitals are Not evaluable (#343)", {
  dfVS <- rep_vs(list(A = c(1, 1)))
  dfSubj <- data.frame(
    studyid = "S1", subjid = c("A", "B"), invid = "I1", country = "US"
  )
  lClass <- rep_Classify(rep_listings(dfVS, dfSubj))
  expect_equal(flag_of(lClass, "A"), "Not evaluable")
  expect_equal(flag_of(lClass, "B"), "Not evaluable")
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$n_records[df$subjid == "B"], 0)
  expect_true(is.na(df$rate[df$subjid == "A"]))
})

test_that("window length comes from the metrics and warns on a mismatch (#343)", {
  dfVS <- rep_vs(list(A = c(1, 1, 2, 2, 2)))
  lClass <- rep_Classify(rep_listings(dfVS), rep_metrics(nWindow = 2))
  expect_equal(lClass$meta$window_length, 2)
  expect_equal(lClass$meta$window_source, "metrics")
  expect_equal(lClass$participants$Numerator[1], 3)

  expect_warning(
    lClass <- rep_Classify(rep_listings(dfVS), rep_metrics(), nWindowLength = 4),
    "kri0020"
  )
  expect_equal(lClass$meta$window_length, 3)

  lClass <- rep_Classify(rep_listings(dfVS), nWindowLength = 4)
  expect_equal(lClass$meta$window_source, "argument")
  expect_equal(lClass$meta$window_length, 4)

  lClass <- rep_Classify(rep_listings(dfVS))
  expect_equal(lClass$meta$window_source, "default")
  expect_equal(lClass$meta$window_length, 3)
})

test_that("vitals without a KRI are windowed and flagged with the participant rule (#343)", {
  dfVS <- rep_vs(list(A = c(170, 170, 170)), "height")
  dfVS$weight <- c(1, 2, 3)
  dfVS$bsa <- c(2, 2, 2)
  lClass <- rep_Classify(rep_listings(dfVS))
  df <- lClass$participants
  vKRI <- rep_Vitals()$vital[!is.na(rep_Vitals()$metric)]
  expect_equal(df$vital, c(vKRI, "height", "bsa"))
  df <- df[df$vital %in% c("weight", "height", "bsa"), ]
  # Count rule: Amber at 2 repeating windows; weight never repeats.
  expect_equal(as.character(df$flag), c("Green", "Green", "Green"))
  expect_false("No KRI" %in% names(rep_FlagColors()))
  expect_equal(df$Numerator, c(0, 1, 1))
  expect_equal(df$metric, c("kri0020a", NA, NA))
  expect_true(all(lClass$measurements$in_repeat_window[lClass$measurements$vital == "height"]))
})

test_that("only enrolled participants are classified, with site and country from Mapped_SUBJ (#343)", {
  dfVS <- rep_vs(list(A = c(1, 1, 1), X = c(1, 1, 1)))
  dfVS$invid <- "stale"
  dfSubj <- data.frame(studyid = "S1", subjid = "A", invid = "I9", country = "FR")
  lClass <- rep_Classify(rep_listings(dfVS, dfSubj))
  expect_equal(unique(lClass$participants$subjid), "A")
  expect_equal(unique(lClass$measurements$subjid), "A")
  expect_equal(unique(lClass$measurements$invid), "I9")
  expect_equal(unique(lClass$participants$country), "FR")
})

test_that("an empty or missing Mapped_VS leaves every participant Not evaluable (#343)", {
  dfSubj <- data.frame(studyid = "S1", subjid = c("A", "B"), invid = "I1", country = "US")
  for (dfVS in list(NULL, rep_vs(list(A = 1))[0, ])) {
    lClass <- rep_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj))
    expect_equal(nrow(lClass$measurements), 0)
    expect_true(all(lClass$participants$flag == "Not evaluable"))
    expect_setequal(unique(lClass$participants$vital), rep_Vitals()$vital[!is.na(rep_Vitals()$metric)])
  }
})

test_that("rep_Classify() rejects a Mapped_SUBJ without site and country (#343)", {
  expect_error(
    rep_Classify(list(Mapped_SUBJ = data.frame(subjid = "A"))),
    "invid"
  )
})

test_that("site and country sums reconcile with all twelve repeat-measure workflows (#343)", {
  TestAtLogLevel()
  vSuffix <- c(weight = "a", pulse = "b", sysbp = "c", diabp = "d", resp = "e", temp = "f")
  vIDs <- c(paste0("kri0020", vSuffix), paste0("cou0020", vSuffix))
  lClass <- rep_Classify(list(
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

  # Known answers from the hand-derived fixture: weight at I1 is 1/5 (20%,
  # the Amber boundary) and at I2 3/10 (30%, the Red boundary).
  lClass <- rep_Classify(vs_fixture())
  lResults <- workr::RunWorkflows(kri_workflow("kri0020a"), vs_fixture())
  dfExpected <- read_fixture("vs_expected_group.csv")
  dfExpected <- dfExpected[dfExpected$measure == "weight" & dfExpected$GroupID %in% c("I1", "I2"), ]
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(as.numeric(tapply(df$Numerator, df$invid, sum)[c("I1", "I2")]), c(1, 3))
  expect_equal(as.numeric(tapply(df$Denominator, df$invid, sum)[c("I1", "I2")]), c(5, 10))
  dfKRI <- lResults$Analysis_kri0020a$Analysis_Flagged
  expect_equal(dfKRI$Flag[match(c("I1", "I2"), dfKRI$GroupID)], c(1, 2))
  expect_equal(dfExpected$Flag, c(1, 2))
})

test_that("Qual: participant N, D and flags match an independent derivation (#343)", {
  dfVS <- mapped_data$Mapped_VS
  dfSubj <- mapped_data$Mapped_SUBJ
  lClass <- rep_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj))
  lRate <- rep_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj), strFlagRule = "rate", nMinWindows = 2)

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
  lListings <- rep_FixtureEdge()
  lListings$Mapped_SUBJ$invid[2] <- ""
  lClass <- rep_Classify(lListings)
  df <- unique(lClass$participants[c("subjid", "invid", "country")])
  expect_equal(df$country, c("(missing)", "X\" data-x=\"1 'q'"))
  expect_equal(df$invid, c("S4", "(missing)"))
  expect_equal(unique(lClass$measurements$country[lClass$measurements$subjid == "F"]), "(missing)")
})

test_that("a site with participants in two countries warns and keeps each participant's country (#343)", {
  expect_warning(
    lClass <- rep_Classify(rep_FixtureSplit()),
    "1 site(s) have participants in more than one country: S2",
    fixed = TRUE
  )
  expect_equal(lClass$meta$split_sites, "S2")
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$country, c("US", "US", "JP"))
  expect_equal(rep_Classify(rep_Fixture())$meta$split_sites, character(0))
})

test_that("participants without a site in different countries are not a split site (#343)", {
  lListings <- rep_FixtureSplit()
  lListings$Mapped_SUBJ$invid <- c("S1", NA, "")
  expect_no_warning(lClass <- rep_Classify(lListings))
  expect_equal(lClass$meta$split_sites, character(0))
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$invid, c("S1", "(missing)", "(missing)"))
  expect_equal(df$country, c("US", "US", "JP"))
})

test_that("participant N and D are the Detect_ConsecutiveRepeats() output and flags use gsm.core::Flag() (#342, #343)", {
  dfVS <- mapped_data$Mapped_VS
  dfSubj <- mapped_data$Mapped_SUBJ
  lClass <- rep_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj))
  dfVS <- dfVS[dfVS$subjid %in% dfSubj$subjid, ]
  dfVS$bp <- ifelse(is.na(dfVS$sysbp) | is.na(dfVS$diabp), NA, paste0(dfVS$sysbp, "/", dfVS$diabp))
  for (strVital in lClass$vitals$vital) {
    dfDetect <- Detect_ConsecutiveRepeats(dfVS, strVital, strOrderCol = "visit")
    df <- lClass$participants[lClass$participants$vital == strVital, ]
    df <- df[match(dfDetect$subjid, df$subjid), ]
    expect_equal(df$Numerator, dfDetect$Numerator, label = strVital)
    expect_equal(df$Denominator, dfDetect$Denominator, label = strVital)
  }

  # Known answers for rep_Fixture() at W = 3 (see helper-rep.R).
  df <- rep_Classify(rep_Fixture())$participants
  dfExpected <- data.frame(
    subjid = c("A", "A", "B", "B", "D", "D"),
    vital = c("weight", "pulse", "weight", "pulse", "weight", "height"),
    Numerator = c(2, 0, 0, 1, 1, 1),
    Denominator = c(2, 1, 2, 2, 4, 1)
  )
  df <- df[match(paste(dfExpected$subjid, dfExpected$vital), paste(df$subjid, df$vital)), ]
  expect_equal(df$Numerator, dfExpected$Numerator)
  expect_equal(df$Denominator, dfExpected$Denominator)

  # Equal thresholds leave no Amber band: 2 or more repeating windows are Red.
  lValues <- list(G = c(1, 1, 1, 2), A = c(1, 1, 1, 1, 2), R = c(1, 1, 1, 1, 1))
  lClass <- rep_Classify(rep_listings(rep_vs(lValues)), rep_metrics(), vFlagThresholds = c(2, 2))
  expect_equal(c(flag_of(lClass, "G"), flag_of(lClass, "A"), flag_of(lClass, "R")), c("Green", "Red", "Red"))
})

test_that("a Mapped_SUBJ without studyid gives a missing studyid (#343)", {
  lListings <- rep_Fixture()
  lListings$Mapped_SUBJ$studyid <- NULL
  lClass <- rep_Classify(lListings)
  expect_equal(nrow(lClass$participants), 5 * nrow(lClass$vitals))
  expect_true(all(is.na(lClass$participants$studyid)))
  expect_true(all(is.na(lClass$measurements$studyid)))
})

test_that("a zero-row Mapped_SUBJ classifies no participants or measurements (#343)", {
  f <- rep_Fixture()
  lClass <- rep_Classify(rep_listings(f$Mapped_VS, f$Mapped_SUBJ[0, ]))
  expect_equal(nrow(lClass$participants), 0)
  expect_equal(nrow(lClass$measurements), 0)
  expect_equal(levels(lClass$participants$flag), names(rep_FlagColors()))
  expect_equal(lClass$meta$split_sites, character(0))
})

test_that("a zero-row Mapped_SUBJ without studyid classifies no participants (#343)", {
  f <- rep_Fixture()
  dfSubj <- f$Mapped_SUBJ[0, setdiff(names(f$Mapped_SUBJ), "studyid")]
  lClass <- rep_Classify(rep_listings(f$Mapped_VS, dfSubj))
  expect_equal(nrow(lClass$participants), 0)
  expect_equal(nrow(lClass$measurements), 0)
  expect_type(lClass$participants$studyid, "character")
})

test_that("Mapped_VS columns named like the engine's marks are kept apart from them (#342)", {
  lListings <- rep_Fixture()
  lExpected <- rep_Classify(lListings)
  lListings$Mapped_VS$seq <- "user seq"
  lListings$Mapped_VS$in_repeat_window <- "user flag"
  lListings$Mapped_VS$window_start <- "user start"
  lClass <- rep_Classify(lListings)
  expect_identical(lClass$measurements, lExpected$measurements)
  expect_identical(lClass$participants, lExpected$participants)
  expect_true(all(lClass$records$in_repeat_window == "user flag"))
})

test_that("an extra numeric Mapped_VS column is windowed and flagged without a KRI (#343)", {
  lListings <- rep_Fixture()
  lListings$Mapped_VS$spo2 <- c(98, 98, 98, 97, 1:4, 5, 6, 99, 99, 99, 99, 99, 99)
  lClass <- rep_Classify(lListings)
  dfV <- lClass$vitals[lClass$vitals$vital == "spo2", ]
  expect_equal(nrow(dfV), 1)
  expect_equal(dfV$label, "spo2")
  expect_equal(dfV$short, "spo2")
  expect_true(is.na(dfV$metric))
  expect_equal(utils::tail(lClass$vitals$vital, 2), c("height", "spo2"))

  df <- lClass$participants[lClass$participants$vital == "spo2", ]
  expect_equal(df$subjid, c("A", "B", "C", "D", "E"))
  expect_true(all(is.na(df$metric)))
  expect_equal(df$Numerator, c(1, 0, 0, 4, 0))
  expect_equal(df$Denominator, c(2, 2, 0, 4, 0))
  expect_equal(as.character(df$flag), c("Green", "Green", "Not evaluable", "Red", "Not evaluable"))
  expect_equal(sum(lClass$measurements$vital == "spo2"), 16)

  dt <- rep_DataTable(rep_DataTableWide(lClass), lClass$vitals)
  expect_match(as.character(dt$x$container), 'title="spo2 (no KRI)"', fixed = TRUE)
})

test_that("a window length that matches the metrics does not warn (#343)", {
  dfVS <- rep_vs(list(A = c(1, 1, 2, 2, 2)))
  expect_no_warning(
    lClass <- rep_Classify(rep_listings(dfVS), rep_metrics(nWindow = 3), nWindowLength = 3)
  )
  expect_equal(lClass$meta$window_length, 3)
  expect_equal(lClass$meta$window_source, "metrics")
})

test_that("rep_Classify() rejects a NULL Mapped_SUBJ (#343)", {
  dfVS <- rep_vs(list(A = c(1, 1, 1)))
  expect_error(
    rep_Classify(list(Mapped_VS = dfVS, Mapped_SUBJ = NULL)),
    "Mapped_SUBJ needs subjid, invid, country"
  )
  expect_error(rep_Classify(list(Mapped_VS = dfVS)), "Mapped_SUBJ needs")
})

test_that("a participant listed twice in Mapped_SUBJ keeps the first row (#343)", {
  lListings <- rep_Fixture()
  lListings$Mapped_SUBJ <- rbind(
    lListings$Mapped_SUBJ,
    data.frame(studyid = "STUDY1", subjid = "A", invid = "S9", country = "FR")
  )
  lClass <- rep_Classify(lListings)
  df <- unique(lClass$participants[c("subjid", "invid", "country")])
  expect_equal(df$subjid, c("A", "B", "C", "D", "E"))
  expect_equal(df$invid[df$subjid == "A"], "S1")
  expect_equal(df$country[df$subjid == "A"], "US")
  expect_equal(unique(lClass$measurements$invid[lClass$measurements$subjid == "A"]), "S1")
  expect_false("S9" %in% lClass$participants$invid)
})

test_that("a Mapped_SUBJ row without subjid is listed but its records are dropped silently (#343)", {
  # Current behaviour, pinned: unlike Detect_ConsecutiveRepeats(), which warns
  # on records with a missing subject, rep_Classify() drops them silently.
  lListings <- rep_Fixture()
  lListings$Mapped_SUBJ$subjid[5] <- NA
  dfOrphan <- lListings$Mapped_VS[lListings$Mapped_VS$subjid == "A", ]
  dfOrphan$subjid <- NA
  lListings$Mapped_VS <- rbind(lListings$Mapped_VS, dfOrphan)
  expect_no_warning(lClass <- rep_Classify(lListings))
  df <- unique(lClass$participants[c("subjid", "invid")])
  expect_equal(df$subjid, c("A", "B", "C", "D", NA))
  expect_equal(df$invid[is.na(df$subjid)], "S3")
  dfNA <- lClass$participants[is.na(lClass$participants$subjid), ]
  expect_true(all(dfNA$n_records == 0))
  expect_true(all(dfNA$flag == "Not evaluable"))
  expect_false(anyNA(lClass$measurements$subjid))
  expect_equal(sum(is.na(lClass$records$subjid)), nrow(dfOrphan))
})

test_that("numeric timing and ID columns are not scored as extra measures (#343)", {
  lListings <- rep_Fixture()
  dfVS <- lListings$Mapped_VS
  n <- nrow(dfVS)
  # Constant columns that would be Red for every participant if scored.
  dfVS$vsdy <- 1
  dfVS$visitnum <- 1
  dfVS$VISITDY <- 1
  dfVS$vsseq <- 1
  dfVS$siteid <- 1
  dfVS$spo2 <- 99
  lListings$Mapped_VS <- dfVS
  lClass <- rep_Classify(lListings)
  expect_false(any(c("vsdy", "visitnum", "VISITDY", "vsseq", "siteid") %in% lClass$vitals$vital))
  expect_false(any(c("vsdy", "visitnum") %in% lClass$participants$vital))
  expect_equal(utils::tail(lClass$vitals$vital, 1), "spo2")
  # D's 6 records give 4 repeating windows.
  expect_equal(flag_of(lClass, "D", "spo2"), "Red")
})

test_that("window-mark columns in Mapped_VS are not scored as extra measures (#343)", {
  lListings <- rep_Fixture()
  for (strCol in c("record", "in_repeat_window", "window_start", ".rep_seq", ".rep_in_window", ".rep_window_start")) {
    lListings$Mapped_VS[[strCol]] <- 1
  }
  lClass <- rep_Classify(lListings)
  expect_identical(lClass$vitals, rep_Classify(rep_Fixture())$vitals)
  expect_identical(lClass$participants, rep_Classify(rep_Fixture())$participants)
})

test_that("a character vs_dt is read as ISO dates (#343)", {
  lListings <- rep_listings(rep_vs(list(A = c(7, 5, 7, 7))))
  lListings$Mapped_VS$vs_dt <- c("2024-01-8", "2024-01-9", "2024-01-10", "2024-01-11")
  # The visits run against the dates, so the order comes from the dates.
  lListings$Mapped_VS$visit <- c("V4", "V3", "V2", "V1")
  lClass <- rep_Classify(lListings)
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(c(df$Numerator, df$Denominator), c(0, 2))
  expect_s3_class(lClass$measurements$vs_dt, "Date")
  expect_equal(lClass$measurements$value, c(7, 5, 7, 7))
  expect_equal(rep_DataTableWide(lClass)$weight, c(7, 5, 7, 7))

  lListings$Mapped_VS$vs_dt[1] <- "8 Jan 2024"
  expect_error(rep_Classify(lListings), "can't be read as a date")
})

test_that("only measured, enrolled records need a readable vs_dt (#343)", {
  lListings <- rep_listings(rep_vs(list(A = c(7, 7, 7, NA))))
  lListings$Mapped_VS$vs_dt <- c("2024-01-08", "2024-01-09", "2024-01-10", "8 Jan 2024")
  lOrphan <- lListings$Mapped_VS[1, ]
  lOrphan$subjid <- "Z"
  lOrphan$vs_dt <- "not a date"
  lListings$Mapped_VS <- rbind(lListings$Mapped_VS, lOrphan)
  lClass <- rep_Classify(lListings)
  expect_equal(lClass$records$vs_dt, as.Date(c("2024-01-08", "2024-01-09", "2024-01-10", NA)))
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(c(df$Numerator, df$Denominator), c(1, 1))

  lListings$Mapped_SUBJ <- lListings$Mapped_SUBJ[0, ]
  expect_equal(nrow(rep_Classify(lListings)$participants), 0)
})

test_that("numeric participant IDs become text in every table (#349)", {
  lListings <- rep_listings(rep_vs(list(A = c(7, 7, 7), B = c(1, 2, 3))))
  lListings$Mapped_VS$subjid <- ifelse(lListings$Mapped_VS$subjid == "A", 100000, 10414)
  lListings$Mapped_SUBJ$subjid <- c(100000L, 10414L)
  lClass <- rep_Classify(lListings)
  for (strTable in c("participants", "measurements", "records")) {
    expect_type(lClass[[strTable]]$subjid, "character")
  }
  expect_setequal(lClass$participants$subjid, c("100000", "10414"))
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$Numerator[df$subjid == "100000"], 1)
})
