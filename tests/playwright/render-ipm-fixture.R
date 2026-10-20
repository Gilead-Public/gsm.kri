# Renders Report_IPMonitoring from the testthat edge-case fixture to
# fixture/IPM.html and, without discontinuation data, fixture/IPM_degraded.html.
# Run from the gsm.kri package root after devtools::load_all(".").
source("tests/testthat/helper-ipm.R")
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
# Absolute: rmarkdown resolves a relative output path against the template.
out_dir <- normalizePath("tests/playwright/fixture")
for (bPTD in c(TRUE, FALSE)) {
  # The fixture's data conflicts warn by design.
  suppressWarnings(Report_IPMonitoring(
    lListings = ipm_Fixture(bPTD),
    dSnapshotDate = ipm_FixtureSnapshotDate,
    strOutputDir = out_dir,
    strOutputFile = if (bPTD) "IPM.html" else "IPM_degraded.html"
  ))
}
