# Renders a study and a site bucket widget (both flat `bars`) into one HTML page
# so Playwright can assert canvas render + handle shape without the report.
devtools::load_all(".", quiet = TRUE)
dfC <- tibble::tibble(
  subjid = paste0("S", 1:8),
  studyid = "ST01",
  country = c("USA", "USA", "USA", "USA", "CAN", "CAN", "CAN", "CAN"),
  invid = c("S1", "S1", "S1", "S2", "S3", "S3", "S4", "S4"),
  Category = factor(
    rep(pd_CategoryLevels(90), length.out = 8),
    levels = pd_CategoryLevels(90)
  ),
  death_dy = c(10, 40, NA, NA, 20, NA, NA, NA)
)
study <- Widget_PrematureDeathBucketBar(
  pd_BucketRows(dfC, 90, "studyid"),
  pd_BucketBarSpec(90, "Study"),
  list(chartId = "pd-study-buckets", level = "study")
)
site <- Widget_PrematureDeathBucketBar(
  pd_BucketRows(dfC, 90, "invid", "country"),
  pd_BucketBarSpec(90, "Site"),
  list(chartId = "pd-site-buckets", level = "site")
)
htmltools::save_html(
  htmltools::tagList(
    htmltools::div(id = "pd-study-buckets-wrap", study),
    htmltools::div(id = "pd-site-buckets-wrap", site)
  ),
  file = file.path("tests", "playwright", "fixture", "pd-bucket-harness.html")
)
