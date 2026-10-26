# Renders Report_RepeatMeasurements from the testthat fixture to fixture/RM.html;
# without vital signs or repeat-measure metrics, fixture/RM_degraded.html, and
# with systolic and diastolic BP for participant A, fixture/RM_bp.html.
# Run from the gsm.kri package root after devtools::load_all(".").
source("tests/testthat/helper-rm.R")
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
# Absolute: rmarkdown resolves a relative output path against the template.
out_dir <- normalizePath("tests/playwright/fixture")
f <- rm_Fixture()
Report_RepeatMeasurements(
  dfResults = rm_FixtureResults(),
  dfMetrics = rm_FixtureMetrics(),
  lListings = f,
  strOutputDir = out_dir,
  strOutputFile = "RM.html"
)
Report_RepeatMeasurements(
  lListings = rm_listings(f$Mapped_VS[0, ], f$Mapped_SUBJ),
  strOutputDir = out_dir,
  strOutputFile = "RM_degraded.html"
)
# Paired BP: A's SBP repeats in both windows, DBP and the pair in one.
fBP <- f
fBP$Mapped_VS$sysbp <- ifelse(fBP$Mapped_VS$subjid == "A", 120, NA)
fBP$Mapped_VS$diabp <- ifelse(fBP$Mapped_VS$subjid == "A", c(80, 80, 80, 81), NA)
Report_RepeatMeasurements(
  dfMetrics = rm_FixtureMetrics(),
  lListings = fBP,
  strOutputDir = out_dir,
  strOutputFile = "RM_bp.html"
)
