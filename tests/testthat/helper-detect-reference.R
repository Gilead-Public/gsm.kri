# Frozen reference: the rle-based Detect_ConsecutiveRepeats() released in
# gsm.kri v1.8.0 (git show v1.8.0:R/Detect_ConsecutiveRepeats.R), without its
# argument checks. The current version adds the shared windowing engine and
# drops records with a missing subject; for every other input it must agree
# with this one exactly. Do not edit to follow the package code.
Detect_ConsecutiveRepeats_v1.8.0 <- function(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strOrderCol = NULL,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
) {
  if (!is.null(strMeasureCol)) {
    df <- df[df[[strMeasureCol]] %in% strMeasureVal, , drop = FALSE]
  }

  vSubjects <- unique(df[[strSubjectCol]])
  df <- df[!is.na(df[[strValueCol]]), , drop = FALSE]
  df <- dplyr::arrange(
    df,
    dplyr::pick(dplyr::all_of(c(strSubjectCol, strDateCol, strOrderCol)))
  )

  lBySubject <- split(
    df[[strValueCol]],
    factor(df[[strSubjectCol]], levels = vSubjects)
  )
  nNumerator <- vapply(
    lBySubject,
    function(x) {
      nRuns <- rle(x)$lengths
      sum(pmax(0, nRuns - nWindowLength + 1))
    },
    numeric(1)
  )
  nDenominator <- pmax(0, lengths(lBySubject) - nWindowLength + 1)

  dfOut <- data.frame(
    SubjectID = vSubjects,
    Numerator = unname(nNumerator),
    Denominator = unname(as.numeric(nDenominator))
  )
  names(dfOut)[1] <- strSubjectCol
  dfOut
}

# Random vital-sign records: few distinct values so runs are common, repeated
# dates so ties are common, NAs, shuffled rows and subjects of all sizes.
detect_random_vs <- function(nSubjects = 6, nMaxRecords = 12, nValues = 3, pNA = 0.15) {
  lSubj <- lapply(seq_len(nSubjects), function(i) {
    n <- sample(0:nMaxRecords, 1)
    if (n == 0) {
      return(NULL)
    }
    value <- sample(seq_len(nValues), n, replace = TRUE)
    value[stats::runif(n) < pNA] <- NA
    data.frame(
      subjid = sprintf("S%02d", i),
      vs_dt = as.Date("2024-01-01") + sort(sample(0:(n %/% 2 + 1), n, replace = TRUE)),
      visit = sprintf("V%02d", sample.int(n)),
      value = value,
      measure = sample(c("WT", "HR"), n, replace = TRUE)
    )
  })
  df <- do.call(rbind, lSubj)
  if (is.null(df)) {
    df <- data.frame(
      subjid = character(), vs_dt = as.Date(character()), visit = character(),
      value = numeric(), measure = character()
    )
  }
  df[sample.int(nrow(df)), , drop = FALSE]
}
