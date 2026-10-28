# Render a deterministic cross-study widget that explicitly selects srs0002.
source("pkgdown/menus/examples/util/Sim_Studies.R")

sim_data <- Sim_Studies(
  dfMetrics = gsm.core::reportingMetrics,
  n_studies = 2,
  n_sites = 4,
  n_sites_per_study = c(2, 3),
  snapshot_date = as.Date("2025-06-01"),
  seed = 280
)

action_scores <- sim_data$dfResults |>
  dplyr::filter(.data$MetricID == "Analysis_srs0001") |>
  dplyr::mutate(
    MetricID = "Analysis_srs0002",
    Numerator = 5,
    Denominator = 100,
    Metric = 5,
    Score = 5
  )
sim_data$dfResults <- dplyr::bind_rows(sim_data$dfResults, action_scores)

metrics <- gsm.core::reportingMetrics
action_metric <- metrics |>
  dplyr::filter(.data$MetricID == "Analysis_srs0001") |>
  dplyr::mutate(
    ID = "srs0002",
    MetricID = "Analysis_srs0002",
    Abbreviation = "Action-weighted SRS",
    Metric = "Action-weighted Site Risk Score"
  )
metrics <- dplyr::bind_rows(metrics, action_metric)

widget <- Widget_CrossStudyRiskScore(
  dfResults = sim_data$dfResults,
  dfMetrics = metrics,
  dfGroups = sim_data$dfGroups,
  strRiskScoreMetric = "Analysis_srs0002"
)

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
htmlwidgets::saveWidget(
  widget,
  file.path(
    normalizePath("tests/playwright/fixture"),
    "CrossStudyActionSRS.html"
  ),
  selfcontained = TRUE
)
cat("Rendered: tests/playwright/fixture/CrossStudyActionSRS.html\n")