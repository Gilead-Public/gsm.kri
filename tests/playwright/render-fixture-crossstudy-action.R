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
# Render the default srs0001 view with srs0002 as the adjacent comparison
# column and dated action detail for the recent-action highlights.
comparison_results <- dplyr::bind_rows(
  dplyr::filter(sim_data$dfResults, .data$MetricID != "Analysis_srs0002"),
  dplyr::mutate(action_scores, Score = 125 / 3, Metric = 125 / 3)
)
flagged <- sim_data$dfResults |>
  dplyr::filter(grepl("^Analysis_kri", .data$MetricID), .data$Flag %in% c(-2, 2)) |>
  dplyr::arrange(.data$StudyID, .data$GroupID, .data$MetricID) |>
  dplyr::slice_head(n = 3)
detail <- flagged |>
  dplyr::transmute(
    .data$StudyID, .data$GroupID, .data$MetricID,
    ActionState = c("Closed Action", "Open Action", "No Action"),
    DaysSinceAction = c(20L, 10L, 120L),
    LastActionedDate = .data$SnapshotDate - .data$DaysSinceAction,
    ActionWindowDays = 90L
  )
write.csv(detail[c("StudyID", "GroupID", "MetricID", "ActionState")],
  file.path(normalizePath("tests/playwright/fixture"), "CrossStudyActionHighlight.csv"),
  row.names = FALSE)

highlight_widget <- Widget_CrossStudyRiskScore(
  dfResults = comparison_results,
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = sim_data$dfGroups,
  dfComparisonRiskDetail = detail
)
htmlwidgets::saveWidget(
  highlight_widget,
  file.path(
    normalizePath("tests/playwright/fixture"),
    "CrossStudyActionHighlight.html"
  ),
  selfcontained = TRUE
)
cat("Rendered: tests/playwright/fixture/CrossStudyActionHighlight.html\n")
