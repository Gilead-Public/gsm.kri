rm_listings <- function(dfVS, dfSubj = NULL) {
  if (is.null(dfSubj)) {
    dfSubj <- data.frame(
      studyid = "S1",
      subjid = unique(dfVS$subjid),
      invid = "I1",
      country = "US"
    )
  }
  list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj)
}

rm_vs <- function(lValues, strCol = "weight") {
  do.call(rbind, lapply(names(lValues), function(id) {
    x <- lValues[[id]]
    df <- data.frame(
      subjid = id,
      vs_dt = as.Date("2024-01-01") + seq_along(x) - 1,
      visit = paste0("V", seq_along(x))
    )
    df[[strCol]] <- x
    df
  }))
}

rm_metrics <- function(nWindow = 3, strThreshold = "0.2,0.3") {
  data.frame(
    ID = c("kri0020a", "cou0020a"),
    MetricID = c("Analysis_kri0020a", "Analysis_cou0020a"),
    WindowLength = nWindow,
    Threshold = strThreshold
  )
}

flag_of <- function(lClass, id, strVital = "weight") {
  df <- lClass$participants
  as.character(df$flag[df$subjid == id & df$vital == strVital])
}

test_that("rate rule flags participants at the 20% and 30% boundaries (#343)", {
  # D = 10 windows: 2 repeats = 20%, 3 repeats = 30%.
  lValues <- list(
    G = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
    A = c(1, 1, 1, 1, 3, 4, 5, 6, 7, 8, 9, 10),
    R = c(1, 1, 1, 1, 1, 4, 5, 6, 7, 8, 9, 10)
  )
  lClass <- rm_Classify(rm_listings(rm_vs(lValues)), rm_metrics())
  df <- lClass$participants[lClass$participants$vital == "weight", ]
  expect_equal(df$Numerator, c(1, 2, 3))
  expect_equal(df$Denominator, c(10, 10, 10))
  expect_equal(as.character(df$flag), c("Green", "Amber", "Red"))
  expect_equal(df$rate, c(0.1, 0.2, 0.3))
})

test_that("count rule flags 1 window Amber and 2 windows Red (#343)", {
  lValues <- list(
    G = c(1, 2, 3, 4),
    A = c(1, 1, 1, 2),
    R = c(1, 1, 1, 1)
  )
  lClass <- rm_Classify(
    rm_listings(rm_vs(lValues)),
    strFlagRule = "count"
  )
  expect_equal(flag_of(lClass, "G"), "Green")
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(flag_of(lClass, "R"), "Red")
  expect_equal(lClass$meta$rule, "count")
})

test_that("thresholds come from each vital's site metric (#343)", {
  lValues <- list(A = c(1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
  lClass <- rm_Classify(
    rm_listings(rm_vs(lValues)),
    rm_metrics(strThreshold = "0.05,0.5")
  )
  expect_equal(flag_of(lClass, "A"), "Amber")
  expect_equal(lClass$meta$thresholds$weight, c(0.05, 0.5))
  expect_equal(lClass$meta$thresholds$pulse, c(0.2, 0.3))
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

test_that("vitals without a KRI are windowed but not flagged (#343)", {
  dfVS <- rm_vs(list(A = c(170, 170, 170)), "height")
  dfVS$weight <- c(1, 2, 3)
  dfVS$bsa <- c(2, 2, 2)
  lClass <- rm_Classify(rm_listings(dfVS))
  df <- lClass$participants
  expect_equal(df$vital, c(rm_Vitals()$vital[1:6], "height", "bsa"))
  df <- df[df$vital %in% c("weight", "height", "bsa"), ]
  expect_equal(as.character(df$flag), c("Green", "No KRI", "No KRI"))
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
    expect_setequal(unique(lClass$participants$vital), rm_Vitals()$vital[1:6])
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

  # Pairwise definition of a repeat window, independent of run lengths.
  dfVS <- dfVS[dfVS$subjid %in% dfSubj$subjid, ]
  for (strVital in c("weight", "pulse", "sysbp", "diabp", "resp", "temp")) {
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
      ifelse(vRate >= 0.3, "Red", ifelse(vRate >= 0.2, "Amber", "Green"))
    )
    dfActual <- lClass$participants[lClass$participants$vital == strVital, ]
    dfActual <- dfActual[match(names(lSubj), dfActual$subjid), ]
    expect_equal(dfActual$Numerator, unname(vN), label = strVital)
    expect_equal(dfActual$Denominator, unname(vD), label = strVital)
    expect_equal(as.character(dfActual$flag), unname(vFlag), label = strVital)
  }
  expect_true(any(lClass$participants$flag == "Red"))
})
