dfResults <- tibble::tibble(
  GroupID = c("Study01", "Study01", "Study01"),
  GroupLevel = rep("Study", 3),
  Numerator = c(5),
  Denominator = c(20),
  Metric = c(0.25),
  Score = c(5),
  Flag = c(2),
  MetricID = rep("study_eligibility", 3),
  SnapshotDate = rep(as.Date("2025-01-01"), 3)
)

dfMetrics <- tibble::tibble(
  MetricID = "study_eligibility",
  nPropRate = 0.3,
  nNumDeviations = 3
)

dfGroups <- tibble::tibble(
  GroupID = "Study01",
  Param = "studyid",
  Value = "Study01",
  GroupLevel = "Study"
)

# Two sites x two countries, mixed Source values, and comma-separated
# ietestcd_concat (the delimiter criteria_groupBar's separate_longer_delim
# expects) so the four "Criteria/..." tabs carry real categories/series
# instead of rendering empty (#286).
dfEXCLUSION <- tibble::tribble(
  ~studyid, ~invid, ~country, ~subjid, ~Source, ~ietestcd_concat, ~dvdtm, ~eligibility_criteria,
  "Study01", "Site01", "US", "Participant01", "Eligibility IPD", "I001,E010", "2025-01-01 00:00:00", "Inclusion/Exclusion description",
  "Study01", "Site01", "US", "Participant02", "EDC", "I002", "2025-01-02 00:00:00", "Inclusion/Exclusion description",
  "Study01", "Site01", "US", "Participant03", "Neither", NA_character_, "2025-01-03 00:00:00", NA_character_,
  "Study01", "Site02", "CA", "Participant04", "EDC", "E010,E020", "2025-01-04 00:00:00", "Inclusion/Exclusion description",
  "Study01", "Site02", "CA", "Participant05", "Eligibility IPD", "I001", "2025-01-05 00:00:00", "Inclusion/Exclusion description",
  "Study01", "Site02", "CA", "Participant06", "Neither", NA_character_, "2025-01-06 00:00:00", NA_character_
)

lListings <- list(
  IE_num = dfEXCLUSION %>% dplyr::filter(Source != "Neither"),
  IE_denom = dfEXCLUSION
)

test_that("Ensure report renders normally {#157}", {
  testthat::skip_if_not_installed("gsm.qtl")
  expect_output(
    Report_Eligibility(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      lListings = lListings,
      strOutputDir = tempdir()
    ) %>%
      grepl(getwd(), .),
    fixed = TRUE
  )
})

test_that("Report_Eligibility renders its 7 bar charts through gsm.vizr-backed gsm.qtl, with the plotly/ggplot2 setup dropped {#286}", {
  testthat::skip_if_not_installed("gsm.qtl")

  # gsm.qtl's eligibility/criteria bar helpers are gsm.vizr::bars()-backed as
  # of #286; the Rmd's plotly/ggplot2 chunk (loaded only for the old widgets)
  # and the fig.height option (only meaningful to knitr's own graphics
  # device -- bars() sizes itself via a minHeight CSS floor) are dead weight.
  rmd_source <- paste(
    readLines(
      system.file("report", "Report_Eligibility.Rmd", package = "gsm.kri"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_false(grepl("library(ggplot2)", rmd_source, fixed = TRUE))
  expect_false(grepl("library(plotly)", rmd_source, fixed = TRUE))
  # Scoped to the bar-chart section: the untouched Time Series chunk (out of
  # scope for #286) keeps its own fig.height, which a whole-file grepl would
  # wrongly catch.
  bar_charts_source <- sub("^.*## Bar Charts", "", rmd_source)
  expect_false(grepl("fig.height=4", bar_charts_source, fixed = TRUE))

  out <- Report_Eligibility(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    lListings = lListings,
    strOutputDir = tempdir()
  )
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Pair each htmlwidget's container div (its class names the widget, e.g.
  # "plotly" pre-migration vs "bars" post-migration) with its adjacent
  # serialized JSON payload, matched on the shared htmlwidget-<hash> id (same
  # technique as test-Report_PrematureDeaths.R's bars-payload assertion).
  widget_pairs <- stringr::str_match_all(
    html,
    '<div class="([a-zA-Z_]+) html-widget[^"]*"[^>]*id="(htmlwidget-[^"]*)"[^>]*></div>\\s*<script[^>]*data-for="\\2">(.*?)</script>'
  )[[1]]
  bars_payloads <- widget_pairs[widget_pairs[, 2] == "bars", 4]

  # Site, Country, Source, and the 4 Criteria/... tabs. The former
  # "Site (by %)" tab is folded into the Site chart's position toggle,
  # mirroring gsm.qtl's QTL0001 report.
  expect_equal(length(bars_payloads), 7)
  expect_false(grepl("Site (by %)", html, fixed = TRUE))
  expect_false(any(widget_pairs[, 2] == "plotly"))
  expect_false(grepl("js-plotly-plot", html, fixed = TRUE))
})
