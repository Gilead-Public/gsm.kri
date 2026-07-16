# Renders a site-level Standard KRI report to fixture/Report_KRI.html using the
# bundled gsm.core reporting example data (mirrors Report_KRI @examples). This
# report exercises the in-use gsm.viz entrypoints re-based by the 2.4.0 upgrade:
# barChart, scatterPlot, timeSeries, and groupOverview.
# Source this with the gsm.kri package loaded and the working directory at the
# package root so the relative fixture path resolves.
library(dplyr)

lChartsSite <- MakeCharts(
  dfResults = gsm.core::reportingResults,
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  dfBounds = gsm.core::reportingBounds
)

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)

# Absolute strOutputDir: RenderRmd shifts the working directory mid-render, so a
# relative path would resolve against the wrong base. normalizePath runs after
# dir.create so the directory already exists.
out <- Report_KRI(
  lCharts = lChartsSite,
  dfResults = gsm.core::reportingResults %>%
    FilterByLatestSnapshotDate() %>%
    gsm.reporting::CalculateChange(gsm.core::reportingResults),
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  strOutputDir = normalizePath("tests/playwright/fixture"),
  strOutputFile = "Report_KRI.html"
)
cat("Rendered:", out, "\n")
