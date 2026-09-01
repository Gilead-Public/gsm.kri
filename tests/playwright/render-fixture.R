# Renders Report_PrematureDeaths to fixture/Report.html with a fixed
# 3-country / 3-site / 2-death dataset (mirrors test-Report_PrematureDeaths.R),
# giving the Playwright specs a deterministic multicategory report.
# Run from the gsm.kri package root:
#   R --quiet -e 'devtools::load_all("."); source("tests/playwright/render-fixture.R")'
dfResults <- tibble::tibble(
  GroupID = c("S1", "S2", "S3", "S4"),
  GroupLevel = "Subject",
  MetricID = "Analysis_pat0015",
  Numerator = c(1, 1, 0, 0),
  Denominator = 1,
  Metric = c(1, 1, 0, 0),
  Score = c(1, 1, 0, 0),
  Flag = c(2, 2, 0, 0),
  SnapshotDate = as.Date("2026-05-01")
)
dfMetrics <- tibble::tibble(
  MetricID = "Analysis_pat0015",
  Metric = "Premature Death (Subject)"
)
dfGroups <- tibble::tibble(
  GroupID = c("S1", "S2", "S3", "S4"),
  Param = "subjid",
  Value = c("S1", "S2", "S3", "S4"),
  GroupLevel = "Subject"
)
lListings <- list(
  Mapped_SUBJ = tibble::tibble(
    studyid = "ST01",
    subjid = c("S1", "S2", "S3", "S4"),
    # S1/USA and S2/CAN each own one death with a distinct reason, so a country
    # click narrows the reasons bar to a strict subset of the study-wide slice
    # (the country-reactive swap the reasons spec exercises). S4/MEX is enrolled
    # with no death and no discontinuation: the bucket charts still draw it, but
    # it owns no reason slice, so it covers the zero-premature-death country the
    # reasons swap has to blank rather than fall back on.
    invid = c("INV-1", "INV-2", "INV-2", "INV-3"),
    country = c("USA", "CAN", "CAN", "MEX"),
    # pd_Classify() anchors the death window on randomization, so rgmn_dt is
    # required on every subject (it errors otherwise).
    rgmn_dt = as.Date(c("2026-01-26", "2026-01-10", "2026-04-15", "2026-02-01"))
  ),
  Mapped_Death = tibble::tibble(
    subjid = c("S1", "S2"),
    death_dt = as.Date(c("2026-02-15", "2026-03-01")),
    death_dy = c(20, 50),
    death_reason = c("Cardiac arrest", "Sepsis"),
    # "Treatment Related" derives from deathcls + aerel (LIST-1), not a boolean.
    deathcls = c("Adverse Event", "Disease Progression"),
    aerel = c("Yes", "No")
  ),
  # S3 (CAN / INV-2) discontinues within the window -> dark-grey bucket.
  Mapped_STUDCOMP = tibble::tibble(
    studyid = "ST01",
    subjid = "S3",
    compyn = "N",
    compreas = "Withdrawal by Subject",
    mincreated_dts = as.Date("2026-05-30")
  )
)
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
# Absolute path: RenderRmd hands a relative output_file to rmarkdown::render,
# which shifts the working directory mid-render, so a relative strOutputDir
# would resolve against the wrong base (mirrors how the testthat render uses
# tempdir()). normalizePath runs after dir.create so the dir already exists.
out <- gsm.kri::Report_PrematureDeaths(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings,
  nWindowDays = 90,
  strOutputDir = normalizePath("tests/playwright/fixture"),
  strOutputFile = "Report.html"
)
cat("Rendered:", out, "\n")
