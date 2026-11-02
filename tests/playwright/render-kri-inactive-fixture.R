# Renders a site KRI report over four bundled metrics to
# fixture/Report_KRI_Inactive.html, with kri0007 flagged inactive, giving
# kri-inactive.spec.js a fixture that renders in seconds.
# Run from the gsm.kri package root:
#   R --quiet -e 'devtools::load_all("."); source("tests/playwright/render-kri-inactive-fixture.R")'
ids <- paste0(
  "Analysis_",
  c("kri0001", "kri0006", "kri0007", "kri0008", "srs0001")
)
keep <- function(df) df[df$MetricID %in% ids, ]
dfMetrics <- keep(gsm.core::reportingMetrics)
dfMetrics$Active <- dfMetrics$MetricID != "Analysis_kri0007"
dfResults <- keep(gsm.core::reportingResults)

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)

# Absolute strOutputDir: RenderRmd shifts the working directory mid-render.
out <- Report_KRI(
  lCharts = MakeCharts(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    dfBounds = keep(gsm.core::reportingBounds)
  ),
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = gsm.core::reportingGroups,
  strOutputDir = normalizePath("tests/playwright/fixture"),
  strOutputFile = "Report_KRI_Inactive.html"
)
cat("Rendered:", out, "\n")
