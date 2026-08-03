# Renders the study-level Eligibility report to fixture/Report_Eligibility.html
# from the same known-good inputs as tests/testthat/test-Report_Eligibility.R.
# This report exercises the gsm.viz timeSeries + barChart entrypoints.
# Source this with the gsm.kri package loaded and the working directory at the
# package root so the relative fixture path resolves.
library(dplyr)

dfResults <- tibble::tibble(
  GroupID = c("Study01", "Study01", "Study01"),
  GroupLevel = rep("Study", 3),
  Numerator = c(5),
  Denominator = c(20),
  Metric = c(0.25),
  Score = c(5),
  Flag = c(2),
  MetricID = rep("study_eligibility", 3),
  SnapshotDate = rep(as.Date("2025-01-01"), 3)
)
dfMetrics <- tibble::tibble(
  MetricID = "study_eligibility",
  nPropRate = 0.3,
  nNumDeviations = 3
)
dfGroups <- tibble::tibble(
  GroupID = "Study01",
  Param = "studyid",
  Value = "Study01",
  GroupLevel = "Study"
)
dfEXCLUSION <- tibble::tibble(
  studyid = "Study01",
  invid = "Site01",
  country = "US",
  subjid = "Participant01",
  Source = "Eligibility IPD",
  ietestcd_concat = NA,
  dvdtm = "2025-01-01 00:00:00",
  eligibility_criteria = "Inclusion/Exclusion description"
)
lListings <- list(
  IE_num = dfEXCLUSION %>% dplyr::filter(Source != "Neither"),
  IE_denom = dfEXCLUSION
)

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)

out <- Report_Eligibility(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings,
  strOutputDir = normalizePath("tests/playwright/fixture"),
  strOutputFile = "Report_Eligibility.html"
)
cat("Rendered:", out, "\n")
