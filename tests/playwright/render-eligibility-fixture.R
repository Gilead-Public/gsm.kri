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
# Two sites x two countries, mixed Source values, and comma-separated
# ietestcd_concat (the delimiter criteria_groupBar's separate_longer_delim
# expects) so the four "Criteria/..." tabs carry real categories/series
# instead of rendering empty (#286).
dfEXCLUSION <- tibble::tribble(
  ~studyid  , ~invid   , ~country , ~subjid         , ~Source           , ~ietestcd_concat , ~dvdtm                , ~eligibility_criteria             ,
  "Study01" , "Site01" , "US"     , "Participant01" , "Eligibility IPD" , "I001,E010"      , "2025-01-01 00:00:00" , "Inclusion/Exclusion description" ,
  "Study01" , "Site01" , "US"     , "Participant02" , "EDC"             , "I002"           , "2025-01-02 00:00:00" , "Inclusion/Exclusion description" ,
  "Study01" , "Site01" , "US"     , "Participant03" , "Neither"         , NA_character_    , "2025-01-03 00:00:00" , NA_character_                     ,
  "Study01" , "Site02" , "CA"     , "Participant04" , "EDC"             , "E010,E020"      , "2025-01-04 00:00:00" , "Inclusion/Exclusion description" ,
  "Study01" , "Site02" , "CA"     , "Participant05" , "Eligibility IPD" , "I001"           , "2025-01-05 00:00:00" , "Inclusion/Exclusion description" ,
  "Study01" , "Site02" , "CA"     , "Participant06" , "Neither"         , NA_character_    , "2025-01-06 00:00:00" , NA_character_
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
