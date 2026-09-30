# Renders Report_IPCompliance from the testthat edge-case fixture to
# fixture/IPC.html and, without discontinuation data, fixture/IPC_degraded.html.
# Run from the gsm.kri package root after devtools::load_all(".").
source("tests/testthat/helper-ipc.R")
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
# Absolute: rmarkdown resolves a relative output path against the template.
out_dir <- normalizePath("tests/playwright/fixture")
for (bPTD in c(TRUE, FALSE)) {
  # The fixture's data conflicts warn by design.
  suppressWarnings(Report_IPCompliance(
    lListings = ipc_Fixture(bPTD),
    dSnapshotDate = ipc_FixtureSnapshotDate,
    strOutputDir = out_dir,
    strOutputFile = if (bPTD) "IPC.html" else "IPC_degraded.html"
  ))
}
