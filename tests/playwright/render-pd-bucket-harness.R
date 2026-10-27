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
# Widget_PrematureDeathBucketBar() is gone (#288); pd_BucketBarSpec()/
# pd_BucketRows() are unchanged, so the same rows/spec now go straight to
# gsm.vizr::bars(), mirroring the report chunks in Report_PrematureDeaths.Rmd.
study <- gsm.vizr::bars(
  data = pd_BucketRows(dfC, 90, "studyid"),
  spec = pd_BucketBarSpec(90, "Study"),
  metadata = list(chartId = "pd-study-buckets", level = "study")
)
site <- gsm.vizr::bars(
  data = pd_BucketRows(dfC, 90, "invid", "country"),
  spec = pd_BucketBarSpec(90, "Site"),
  metadata = list(chartId = "pd-site-buckets", level = "site")
)
htmltools::save_html(
  htmltools::tagList(
    htmltools::div(id = "pd-study-buckets-wrap", study),
    htmltools::div(id = "pd-site-buckets-wrap", site)
  ),
  file = file.path("tests", "playwright", "fixture", "pd-bucket-harness.html")
)
