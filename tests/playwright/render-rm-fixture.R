# Renders Report_RepeatMeasurements from the testthat fixture to fixture/RM.html
# and, without vital signs or repeat-measure metrics, fixture/RM_degraded.html.
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
