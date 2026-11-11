# Renders Report_RepeatMeasurements from the testthat fixture to fixture/RM.html;
# without vital signs or repeat-measure metrics, fixture/RM_degraded.html, and
# with systolic and diastolic BP for participant A, fixture/RM_bp.html; and
# with a missing country, a quoted country and a 2/3 threshold, fixture/RM_edge.html;
# and a site that spans countries, fixture/RM_split.html; and under the rate
# rule a Green participant with more repeat windows than a Red one,
# fixture/RM_rate.html; and IDs with HTML, a split site and a metric
# Threshold of 25% / 40% under the rate rule, fixture/RM_html.html.
# Run from the gsm.kri package root after devtools::load_all(".").
source("tests/testthat/helper-rep.R")
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
# Absolute: rmarkdown resolves a relative output path against the template.
out_dir <- normalizePath("tests/playwright/fixture")
f <- rep_Fixture()
Report_RepeatMeasurements(
  dfResults = rep_FixtureResults(),
  dfMetrics = rep_FixtureMetrics(),
  lListings = f,
  strOutputDir = out_dir,
  strOutputFile = "RM.html"
)
Report_RepeatMeasurements(
  lListings = rep_listings(f$Mapped_VS[0, ], f$Mapped_SUBJ),
  strOutputDir = out_dir,
  strOutputFile = "RM_degraded.html"
)
# Paired BP: A's SBP repeats in both windows, DBP and the pair in one.
fBP <- f
fBP$Mapped_VS$sysbp <- ifelse(fBP$Mapped_VS$subjid == "A", 120, NA)
fBP$Mapped_VS$diabp <- ifelse(fBP$Mapped_VS$subjid == "A", c(80, 80, 80, 81), NA)
Report_RepeatMeasurements(
  dfMetrics = rep_FixtureMetrics(),
  lListings = fBP,
  strOutputDir = out_dir,
  strOutputFile = "RM_bp.html"
)
# G also has a visit not performed, with every measure missing.
fEdge <- rep_FixtureEdge()
fEdge$Mapped_VS <- rbind(
  fEdge$Mapped_VS,
  data.frame(subjid = "G", visit = "V6", vs_dt = as.Date("2024-01-06"), vsperf_std = "N", weight = NA)
)
Report_RepeatMeasurements(
  dfMetrics = rep_FixtureMetrics(),
  lListings = fEdge,
  strFlagRule = "rate",
  vFlagThresholds = c(0.5, 2 / 3),
  strOutputDir = out_dir,
  strOutputFile = "RM_edge.html"
)
suppressWarnings(Report_RepeatMeasurements(
  dfMetrics = rep_FixtureMetrics(),
  lListings = rep_FixtureSplit(),
  strOutputDir = out_dir,
  strOutputFile = "RM_split.html"
))
# Rate rule, default thresholds: P01 is Green at 2/20 windows, P02 Red at 1/3.
Report_RepeatMeasurements(
  lListings = rep_listings(rep_vs(list(
    P01 = c(1, 1, 1, 1, 2:19),
    P02 = c(1, 1, 1, 2, 3)
  ))),
  strFlagRule = "rate",
  strOutputDir = out_dir,
  strOutputFile = "RM_rate.html"
)
suppressWarnings(Report_RepeatMeasurements(
  dfMetrics = rep_FixtureMetrics(strThreshold = "0.25,0.4"),
  lListings = rep_FixtureHTML(),
  strFlagRule = "rate",
  strOutputDir = out_dir,
  strOutputFile = "RM_html.html"
))
