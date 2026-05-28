library(gsm.kri)
library(dplyr)
library(testthat)

# Source the modified Report_FlagChange to test against dev version
source("R/Report_FlagChange.R")

# Test 1: sort within a single flag group
dfMulti <- data.frame(
  StudyID = "S1", GroupLevel = "Site",
  GroupID = c("G3", "G1", "G2", "G1"),
  MetricID = c("M2", "M2", "M1", "M1"),
  Flag = c(1, 1, 1, 1),
  Flag_Previous = c(0, 0, 0, 0),
  Flag_Change = c(1, 1, 1, 1),
  SnapshotDate = as.Date("2024-01-01"),
  Score = 1.2, Score_Previous = 0.9, Score_Change = 0.3,
  Numerator = 4, Denominator = 5, Metric = 0.8,
  Numerator_Previous = 3, Denominator_Previous = 5, Metric_Previous = 0.6,
  stringsAsFactors = FALSE
)
output <- paste(capture.output(Report_FlagChange(dfMulti)), collapse = "")
pat <- "G[0-9]+ [|] M[0-9]+"
matches <- regmatches(output, gregexpr(pat, output))[[1]]
cat("Test 1 matches:", matches, "\n")
stopifnot(identical(matches, c("G1 | M1", "G2 | M1", "G1 | M2", "G3 | M2")))
cat("Test 1 PASSED\n\n")

# Test 2: sort across flag severity groups
dfMixed <- data.frame(
  StudyID = "S1", GroupLevel = "Site",
  GroupID = c("G2", "G1", "G3", "G1"),
  MetricID = c("M1", "M2", "M1", "M1"),
  Flag = c(2, 2, 1, 1),
  Flag_Previous = c(0, 0, 0, 0),
  Flag_Change = c(2, 2, 1, 1),
  SnapshotDate = as.Date("2024-01-01"),
  Score = 1.5, Score_Previous = 0.5, Score_Change = 1.0,
  Numerator = 5, Denominator = 10, Metric = 0.5,
  Numerator_Previous = 2, Denominator_Previous = 10, Metric_Previous = 0.2,
  stringsAsFactors = FALSE
)
output2 <- paste(capture.output(Report_FlagChange(dfMixed)), collapse = "")
all_matches <- regmatches(output2, gregexpr(pat, output2))[[1]]
cat("Test 2 matches:", all_matches, "\n")
# Red first (sorted): M1-G2, M2-G1
stopifnot(identical(all_matches[1:2], c("G2 | M1", "G1 | M2")))
# Amber next (sorted): M1-G1, M1-G3
stopifnot(identical(all_matches[3:4], c("G1 | M1", "G3 | M1")))
cat("Test 2 PASSED\n")
