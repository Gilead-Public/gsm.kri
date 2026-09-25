# Render GroupOverview fixtures used by Report_KRI with and without an adjacent
# action-weighted SRS. Report_KRI parameter forwarding is covered in testthat;
# this fixture isolates the browser behavior from the legacy report renderer.
library(dplyr)

results <- gsm.core::reportingResults %>% FilterByLatestSnapshotDate()

adjusted <- results %>%
  filter(.data$MetricID == "Analysis_srs0001") %>%
  mutate(
    MetricID = "Analysis_srs0002",
    Score = .data$Score / 2,
    Numerator = .data$Numerator / 2
  )

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)

baseline_widget <- Widget_GroupOverview(
  dfResults = results,
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  strGroupLevel = "Site",
  strGroupSubset = "all"
)
adjusted_widget <- Widget_GroupOverview(
  dfResults = bind_rows(results, adjusted),
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  strGroupLevel = "Site",
  strGroupSubset = "all",
  strComparisonRiskMetric = "Analysis_srs0002",
  strComparisonRiskLabel = "Adjusted Risk Score"
)

htmlwidgets::saveWidget(
  baseline_widget,
  "tests/playwright/fixture/GroupOverviewBaseline.html",
  selfcontained = TRUE
)
htmlwidgets::saveWidget(
  adjusted_widget,
  "tests/playwright/fixture/GroupOverviewAction.html",
  selfcontained = TRUE
)

rmarkdown::render(
  "pkgdown/menus/examples/Example_SiteReport.Rmd",
  output_file = "Example_SiteReport.html",
  output_dir = "tests/playwright/fixture",
  intermediates_dir = tempdir(),
  quiet = TRUE
)
