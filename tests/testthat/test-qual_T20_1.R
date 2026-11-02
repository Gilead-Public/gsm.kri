# Double programming: the expected results are derived independently of
# Detect_ConsecutiveRepeats() and the gsm.core rate pipeline, using a
# pairwise-comparison definition of a repeat window rather than run lengths.
independent_repeats <- function(dfVS, strCol, nWindow = 3) {
  dfVS <- dfVS[!is.na(dfVS[[strCol]]), ]
  dfVS <- dfVS[order(dfVS$subjid, dfVS$vs_dt, dfVS$visit), ]
  lSubj <- split(dfVS[[strCol]], dfVS$subjid)
  data.frame(
    subjid = names(lSubj),
    Numerator = vapply(lSubj, function(x) {
      n <- length(x)
      if (n < nWindow) {
        return(0)
      }
      sum(vapply(seq_len(n - nWindow + 1), function(i) {
        all(x[i:(i + nWindow - 1)] == x[i])
      }, logical(1)))
    }, numeric(1)),
    Denominator = vapply(lSubj, function(x) max(0, length(x) - nWindow + 1), numeric(1))
  )
}

independent_flags <- function(dfSubj, strGroupCol, vThreshold = c(0.2, 0.3), nAccrual = 3) {
  dfGroup <- stats::aggregate(
    cbind(Numerator, Denominator) ~ GroupID,
    data = transform(dfSubj, GroupID = dfSubj[[strGroupCol]]),
    FUN = sum
  )
  dfGroup$Metric <- dfGroup$Numerator / dfGroup$Denominator
  dfGroup$Flag <- ifelse(
    dfGroup$Metric >= vThreshold[2], 2,
    ifelse(dfGroup$Metric >= vThreshold[1], 1, 0)
  )
  dfGroup$Flag[dfGroup$Denominator < nAccrual] <- NA
  dfGroup
}

test_that("Qual: kri0020a-f/cou0020a-f match an independent derivation on lSource (#306)", {
  TestAtLogLevel()
  vCols <- c(a = "weight", b = "pulse", c = "sysbp", d = "diabp", e = "resp", f = "temp")

  dfVS <- mapped_data$Mapped_VS
  dfSUBJ <- mapped_data$Mapped_SUBJ
  # A vacuous comparison would pass trivially.
  expect_gt(nrow(dfVS), 0)

  lResults <- workr::RunWorkflows(
    kri_workflow(c(paste0("kri0020", names(vCols)), paste0("cou0020", names(vCols)))),
    mapped_data
  )

  for (strSuffix in names(vCols)) {
    strCol <- vCols[[strSuffix]]
    dfSubj <- merge(
      dfSUBJ[c("subjid", "invid", "country")],
      independent_repeats(dfVS, strCol),
      by = "subjid"
    )
    expect_gt(sum(dfSubj$Numerator), 0, label = paste(strCol, "numerator"))

    for (strLevel in c("Site", "Country")) {
      strID <- paste0(if (strLevel == "Site") "kri" else "cou", "0020", strSuffix)
      dfExpected <- independent_flags(
        dfSubj,
        if (strLevel == "Site") "invid" else "country"
      )
      dfActual <- lResults[[paste0("Analysis_", strID)]]$Analysis_Summary
      dfActual <- dfActual[match(dfExpected$GroupID, dfActual$GroupID), ]

      expect_equal(dfActual$Numerator, dfExpected$Numerator, label = strID)
      expect_equal(dfActual$Denominator, dfExpected$Denominator, label = strID)
      expect_equal(as.numeric(dfActual$Flag), dfExpected$Flag, label = strID)
    }
  }
})
