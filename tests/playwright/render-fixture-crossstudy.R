# Renders Widget_CrossStudyRiskScore to fixture/CrossStudySRS.html with a small
# deterministic (seeded) multi-study dataset, giving the Playwright specs a
# stable fixture to test "Sort by" and "Filter by Study" behavior against.
# n_sites is small relative to n_sites_per_study so overlap across studies is
# guaranteed (needed to exercise the per-study metric recalculation).
# Run from the gsm.kri package root:
#   R --quiet -e 'devtools::load_all("."); source("tests/playwright/render-fixture-crossstudy.R")'
source("pkgdown/menus/examples/util/Sim_Studies.R")

sim_data <- Sim_Studies(
  dfMetrics = gsm.core::reportingMetrics,
  n_studies = 3,
  n_sites = 6,
  n_sites_per_study = c(4, 5),
  snapshot_date = as.Date("2025-06-01"),
  seed = 123
)

widget <- Widget_CrossStudyRiskScore(
  dfResults = sim_data$dfResults,
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = sim_data$dfGroups
)

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
htmlwidgets::saveWidget(
  widget,
  file.path(normalizePath("tests/playwright/fixture"), "CrossStudySRS.html"),
  selfcontained = TRUE
)
cat("Rendered: tests/playwright/fixture/CrossStudySRS.html\n")
