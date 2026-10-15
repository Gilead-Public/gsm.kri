dfMetricsV2 <- tibble::tibble(
  MetricID = c("Analysis_kri0001", "Analysis_kri0002", "Analysis_srs0001"),
  GroupLevel = "Site",
  Abbreviation = c("AE", "SAE", "SRS"),
  Metric = c("Adverse Event Rate", "Serious Adverse Event Rate", "Site Risk Score"),
  Numerator = c("Adverse Events", "Serious Adverse Events", "Weight"),
  Denominator = c("Days on Study", "Days on Study", "Maximum Weights"),
  Model = c("Normal Approximation", "Normal Approximation", NA),
  Threshold = c("-2,-1,2,3", "-2,-1,2,3", NA)
)

dfResultsV2 <- tibble::tibble(
  StudyID = "S1",
  GroupLevel = "Site",
  GroupID = rep(c("A", "B", "C"), 3),
  MetricID = rep(c("Analysis_kri0001", "Analysis_kri0002", "Analysis_srs0001"), each = 3),
  SnapshotDate = as.Date("2025-04-01"),
  Numerator = c(5, 1, 0, 2, 0, 0, NA, NA, NA),
  Denominator = c(100, 100, 100, 50, 50, 50, NA, NA, NA),
  Metric = c(0.05, 0.01, 0, 0.04, 0, 0, NA, NA, NA),
  Score = c(3.1, 1.2, 0, 2.2, 0.1, 0, 12.5, 4, 0),
  Flag = c(2, 1, 0, -1, 0, 0, NA, NA, NA),
  Flag_Previous = c(1, NA, 0, 0, 1, 0, NA, NA, NA),
  SnapshotDate_Previous = as.Date("2025-03-01"),
  Score_Previous = c(2, NA, 0, 0.5, 1.5, 0, NA, NA, NA),
  Numerator_Previous = c(3, NA, 0, 1, 1, 0, NA, NA, NA),
  Denominator_Previous = c(80, NA, 90, 40, 40, 40, NA, NA, NA),
  Metric_Previous = c(0.0375, NA, 0, 0.025, 0.025, 0, NA, NA, NA),
  Flag_Change = c(1, NA, 0, -1, -1, 0, NA, NA, NA),
  Score_Change = c(1.1, NA, 0, 1.7, -1.4, 0, NA, NA, NA),
  Metric_Change = c(0.0125, NA, 0, 0.015, -0.025, 0, NA, NA, NA),
  Numerator_Change = c(2, NA, 0, 1, -1, 0, NA, NA, NA),
  Denominator_Change = c(20, NA, 10, 10, 10, 10, NA, NA, NA)
)

dfGroupsV2 <- tibble::tribble(
  ~GroupID, ~GroupLevel, ~Param, ~Value,
  "S1", "Study", "nickname", "OAK",
  "S1", "Study", "status", "Active",
  "S1", "Study", "phase", "P2",
  "S1", "Study", "protocol_title", "A Protocol",
  "S1", "Study", "SiteCount", "3",
  "S1", "Study", "SiteTarget", "4",
  "S1", "Study", "ParticipantCount", "30",
  "S1", "Study", "ParticipantTarget", "40",
  "A", "Site", "InvestigatorLastName", "Smith",
  "B", "Site", "InvestigatorLastName", "Doe",
  "C", "Site", "InvestigatorLastName", "Deer"
)

render_html <- function(x) as.character(htmltools::renderTags(x)$html)

test_that("ReportV2_Summary counts current flags, deltas, and change categories", {
  lSummary <- ReportV2_Summary(dfResultsV2)

  expect_equal(lSummary$red, 1)
  expect_equal(lSummary$amber, 2)
  expect_equal(lSummary$red_previous, 0)
  expect_equal(lSummary$amber_previous, 2)
  expect_equal(lSummary$sites_total, 3)
  expect_equal(lSummary$sites_flagged, 2)
  expect_equal(lSummary$sites_red, 1)
  expect_equal(lSummary$sites_clear, 1)
  # A/AE amber->red and A/SAE green->amber escalate; B/SAE amber->green improves; B/AE is new.
  expect_equal(lSummary$escalated, 2)
  expect_equal(lSummary$improved, 1)
  expect_equal(lSummary$new, 1)
})

test_that("ReportV2_Summary leaves deltas missing without previous-snapshot columns", {
  lSummary <- ReportV2_Summary(dplyr::select(dfResultsV2, -"Flag_Previous"))

  expect_true(is.na(lSummary$red_previous))
  expect_true(is.na(lSummary$escalated))
  expect_equal(lSummary$red, 1)
})

test_that("ReportV2_Masthead shows study label, snapshot, and enrollment progress", {
  lSetup <- Report_Setup(dfGroupsV2, dfMetricsV2, dfResultsV2)
  html <- render_html(ReportV2_Masthead(lSetup))

  expect_match(html, "S1 (OAK)", fixed = TRUE)
  expect_match(html, "2025-04-01", fixed = TRUE)
  expect_match(html, "Site KRI Overview", fixed = TRUE)
  expect_match(html, "Participant enrollment", fixed = TRUE)
  expect_match(html, "--p:0.75", fixed = TRUE)
})

test_that("ReportV2_Masthead omits progress bars when targets are unavailable", {
  lSetup <- Report_Setup(
    dplyr::filter(dfGroupsV2, !grepl("Target", .data$Param)),
    dfMetricsV2,
    dfResultsV2
  )
  html <- render_html(ReportV2_Masthead(lSetup))

  expect_no_match(html, "v2-bar")
})

test_that("ReportV2_KPICards renders counts with direction of change", {
  html <- render_html(ReportV2_KPICards(ReportV2_Summary(dfResultsV2)))

  expect_match(html, "Red KRIs", fixed = TRUE)
  expect_match(html, "data-count=\"1\"", fixed = TRUE)
  expect_match(html, "v2-delta up-bad", fixed = TRUE)
  expect_match(html, "Sites without flags", fixed = TRUE)
})

test_that("ReportV2_KPICards omits deltas without previous snapshot", {
  lSummary <- ReportV2_Summary(dplyr::select(dfResultsV2, -"Flag_Previous"))
  html <- render_html(ReportV2_KPICards(lSummary))

  expect_no_match(html, "v2-delta")
})

test_that("ReportV2_Takeaways names the riskiest metric without a risk-score list", {
  html <- render_html(ReportV2_Takeaways(
    ReportV2_Summary(dfResultsV2), dfResultsV2, dfMetricsV2, dfGroupsV2
  ))

  expect_match(html, "Adverse Event Rate", fixed = TRUE)
  expect_match(html, "Key takeaways", fixed = TRUE)
  # Site risk ranking now lives in the Sites tab.
  expect_no_match(html, "Highest site risk scores", fixed = TRUE)
})

test_that("ReportV2_Nav links every KRI with flag badges and excludes SRS", {
  html <- render_html(ReportV2_Nav(dfResultsV2, dfMetricsV2))

  expect_match(html, "href=\"#kri-Analysis_kri0001\"", fixed = TRUE)
  expect_match(html, "href=\"#kri-Analysis_kri0002\"", fixed = TRUE)
  expect_no_match(html, "Analysis_srs0001")
  expect_match(html, "v2-badge red\">1<", fixed = TRUE)
  expect_match(html, "href=\"#v2-reference\"", fixed = TRUE)
  # Overview sections moved to their own tab; the nav only lists KRIs.
  expect_no_match(html, "href=\"#v2-changes\"", fixed = TRUE)
})

count_matches <- function(html, pattern) {
  lengths(regmatches(html, gregexpr(pattern, html, fixed = TRUE)))
}

# The rows of one perspective ("site" or "kri") of the flag-changes card.
change_view <- function(html, strView) {
  sub(
    paste0("(?s).*?data-view-panel=\"", strView, "\"(.*?)</div><!--/", strView, "-->.*"),
    "\\1", html, perl = TRUE
  )
}

test_that("ReportV2_FlagChanges groups changed flags into categories", {
  html <- render_html(ReportV2_FlagChanges(dfResultsV2, dfMetricsV2, dfGroupsV2))

  expect_match(html, "data-cat=\"escalated\"", fixed = TRUE)
  expect_match(html, "data-cat=\"improved\"", fixed = TRUE)
  expect_match(html, "data-cat=\"new\"", fixed = TRUE)
  expect_match(html, "Serious Adverse Event Rate", fixed = TRUE)
  expect_no_match(html, "Analysis_srs0001")
})

test_that("ReportV2_FlagChanges offers site and KRI perspectives over the same changes", {
  html <- render_html(ReportV2_FlagChanges(dfResultsV2, dfMetricsV2, dfGroupsV2))

  expect_match(html, "data-view=\"site\"", fixed = TRUE)
  expect_match(html, "data-view=\"kri\"", fixed = TRUE)
  expect_equal(count_matches(change_view(html, "site"), "class=\"v2-change-row\""), 4)
  expect_equal(count_matches(change_view(html, "kri"), "class=\"v2-change-row\""), 4)

  # Site groups follow the risk score: A (12.5) before B (4).
  strSite <- change_view(html, "site")
  expect_lt(
    regexpr("data-group=\"A\"", strSite, fixed = TRUE),
    regexpr("data-group=\"B\"", strSite, fixed = TRUE)
  )
  expect_match(strSite, "Smith", fixed = TRUE)
  expect_match(change_view(html, "kri"), "data-group=\"Analysis_kri0002\"", fixed = TRUE)
})

test_that("ReportV2_FlagChanges returns NULL without delta columns", {
  expect_null(ReportV2_FlagChanges(
    dplyr::select(dfResultsV2, -"Flag_Previous"), dfMetricsV2, dfGroupsV2
  ))
})

test_that("ReportV2_MetricCard prints a card with tabs for each chart", {
  dummy <- htmltools::tags$div("chart")
  lCharts <- list(scatterPlot = dummy, barChart = dummy)
  attr(lCharts$scatterPlot, "output_label") <- "Scatter Plot"
  attr(lCharts$barChart, "output_label") <- "Bar Chart"
  lMetric <- as.list(dfMetricsV2[1, ])

  out <- paste(capture.output(ReportV2_MetricCard(lCharts, lMetric, dfResultsV2)), collapse = "\n")

  expect_match(out, "id=\"kri-Analysis_kri0001\"", fixed = TRUE)
  expect_match(out, "Scatter Plot", fixed = TRUE)
  expect_match(out, "Bar Chart", fixed = TRUE)
  expect_match(out, "gsm-widget Analysis_kri0001 scatterPlot", fixed = TRUE)
  expect_match(out, "1 red", fixed = TRUE)
  expect_no_match(out, "v2-metric collapsed")
})

test_that("ReportV2_MetricCard collapses metrics without flags", {
  dummy <- htmltools::tags$div("chart")
  lMetric <- as.list(dfMetricsV2[2, ])
  dfResults <- dplyr::mutate(dfResultsV2, Flag = 0)

  out <- paste(capture.output(ReportV2_MetricCard(list(scatterPlot = dummy), lMetric, dfResults)), collapse = "\n")

  expect_match(out, "v2-metric collapsed", fixed = TRUE)
  expect_match(out, "No flags", fixed = TRUE)
})

test_that("ReportV2_MetricReference lists KRI definitions", {
  html <- render_html(ReportV2_MetricReference(dfMetricsV2))

  expect_match(html, "Adverse Event Rate", fixed = TRUE)
  expect_match(html, "Days on Study", fixed = TRUE)
  expect_match(html, "-2,-1,2,3", fixed = TRUE)
  expect_no_match(html, "Site Risk Score")
})

test_that("ReportV2_Dependencies ships stylesheet and script", {
  dep <- ReportV2_Dependencies()

  expect_s3_class(dep, "html_dependency")
  expect_equal(dep$stylesheet, "report_v2.css")
  expect_equal(dep$script, "report_v2.js")
  expect_true(file.exists(system.file("report", "v2", "report_v2.css", package = "gsm.kri")))
  expect_true(file.exists(system.file("report", "v2", "report_v2.js", package = "gsm.kri")))
})

test_that("Report_KRI renders the v2 template", {
  skip_on_cran()
  skip_if_not(rmarkdown::pandoc_available())

  vMetrics <- c("Analysis_kri0001", "Analysis_srs0001")
  dfMetrics <- dplyr::filter(gsm.core::reportingMetrics, .data$MetricID %in% vMetrics)
  dfResults <- dplyr::filter(gsm.core::reportingResults, .data$MetricID %in% vMetrics)
  dfBounds <- dplyr::filter(gsm.core::reportingBounds, .data$MetricID %in% vMetrics)
  lCharts <- suppressWarnings(MakeCharts(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    dfBounds = dfBounds
  ))
  dfResultsDelta <- dfResults %>%
    FilterByLatestSnapshotDate() %>%
    gsm.reporting::CalculateChange(dfResults)

  strOutputDir <- withr::local_tempdir()
  suppressMessages(suppressWarnings(utils::capture.output(Report_KRI(
    lCharts = lCharts,
    dfResults = dfResultsDelta,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    strOutputDir = strOutputDir,
    strOutputFile = "v2.html",
    strInputPath = system.file("report", "Report_KRI_v2.Rmd", package = "gsm.kri")
  ))))

  html <- paste(readLines(file.path(strOutputDir, "v2.html"), warn = FALSE), collapse = "\n")
  expect_match(html, "v2-masthead", fixed = TRUE)
  expect_match(html, "id=\"kri-Analysis_kri0001\"", fixed = TRUE)
  expect_match(html, "v2-site-input", fixed = TRUE)
  expect_no_match(html, "fonts.googleapis.com", fixed = TRUE)
  for (strTab in c("overview", "sites", "metrics")) {
    expect_match(html, paste0("data-tab=\"", strTab, "\""), fixed = TRUE)
  }
  expect_match(html, "id=\"v2-site-table\"", fixed = TRUE)
  expect_match(html, "id=\"v2-site-data\"", fixed = TRUE)
})

# Inactive metrics (#325): Active == FALSE; NA or a missing column means active.
dfMetricsInactive <- dplyr::mutate(dfMetricsV2, Active = c(FALSE, TRUE, NA))

test_that("ReportV2_Summary excludes inactive metrics from counts (#325)", {
  lSummary <- ReportV2_Summary(dfResultsV2, dfMetricsInactive)

  # Only SAE remains: A amber (green->amber escalates), B green (amber->green improves).
  expect_equal(lSummary$red, 0)
  expect_equal(lSummary$amber, 1)
  expect_equal(lSummary$sites_flagged, 1)
  expect_equal(lSummary$sites_clear, 2)
  expect_equal(lSummary$escalated, 1)
  expect_equal(lSummary$improved, 1)
  expect_equal(lSummary$new, 0)
})

test_that("ReportV2_Summary treats metrics as active without an Active column (#325)", {
  expect_equal(ReportV2_Summary(dfResultsV2, dfMetricsV2), ReportV2_Summary(dfResultsV2))
})

test_that("ReportV2_Nav lists inactive metrics in a separate group after active KRIs (#325)", {
  html <- render_html(ReportV2_Nav(dfResultsV2, dfMetricsInactive))

  expect_match(html, "Inactive", fixed = TRUE)
  expect_lt(
    regexpr("#kri-Analysis_kri0002", html, fixed = TRUE),
    regexpr("#kri-Analysis_kri0001", html, fixed = TRUE)
  )
  expect_no_match(html, "v2-badge red\">1<", fixed = TRUE)
})

test_that("ReportV2_Takeaways ignores inactive metrics (#325)", {
  html <- render_html(ReportV2_Takeaways(
    ReportV2_Summary(dfResultsV2, dfMetricsInactive), dfResultsV2, dfMetricsInactive, dfGroupsV2
  ))

  expect_match(html, "<b>Serious Adverse Event Rate</b>", fixed = TRUE)
  expect_no_match(html, "Adverse Event Rate</b> drives", fixed = TRUE)
})

test_that("ReportV2_FlagChanges omits inactive metrics (#325)", {
  html <- render_html(ReportV2_FlagChanges(dfResultsV2, dfMetricsInactive, dfGroupsV2))

  expect_equal(count_matches(change_view(html, "site"), "class=\"v2-change-row\""), 2)
  expect_no_match(html, "data-cat=\"new\"", fixed = TRUE)
})

test_that("ReportV2_MetricCard collapses and labels an inactive metric (#325)", {
  dummy <- htmltools::tags$div("chart")
  lMetric <- as.list(dfMetricsInactive[1, ])

  out <- paste(capture.output(ReportV2_MetricCard(list(scatterPlot = dummy), lMetric, dfResultsV2)), collapse = "\n")

  expect_match(out, "v2-metric inactive collapsed", fixed = TRUE)
  expect_match(out, "v2-badge inactive\">Inactive<", fixed = TRUE)
  expect_no_match(out, "1 red", fixed = TRUE)
})

test_that("ReportV2_MetricReference labels inactive metrics (#325)", {
  html <- render_html(ReportV2_MetricReference(dfMetricsInactive))

  expect_match(html, "v2-badge inactive\">Inactive<", fixed = TRUE)
})

test_that("ReportV2_Topbar search counts exclude inactive metrics (#325)", {
  lSetup <- Report_Setup(dfGroupsV2, dfMetricsInactive, dfResultsV2)
  html <- render_html(ReportV2_Topbar(lSetup, dfResultsV2, dfGroupsV2, dfMetricsInactive))
  dfSites <- jsonlite::fromJSON(sub("(?s).*id=\"v2-sites\">(.*?)</script>.*", "\\1", html, perl = TRUE))

  expect_equal(dfSites$red[dfSites$GroupID == "A"], 0)
  expect_equal(dfSites$amber[dfSites$GroupID == "A"], 1)
})

test_that("ReportV2_MetricCard flags an inactive metric missing from the latest snapshot (#325)", {
  dummy <- htmltools::tags$div("chart")
  lMetric <- as.list(dfMetricsInactive[1, ])
  dfResults <- dplyr::filter(dfResultsV2, .data$MetricID != "Analysis_kri0001")

  out <- paste(capture.output(ReportV2_MetricCard(list(timeSeries = dummy), lMetric, dfResults)), collapse = "\n")

  expect_match(out, "Not in latest snapshot", fixed = TRUE)
  expect_no_match(out, "0 sites", fixed = TRUE)
})

test_that("Report_KRI v2 template lists a retired metric last with only its time series (#325)", {
  skip_on_cran()
  skip_if_not(rmarkdown::pandoc_available())

  # Mirrors the pkgdown example: a retired copy of the Adverse Event Rate,
  # inactive, with results in earlier snapshots only.
  vMetrics <- c("Analysis_kri0001", "Analysis_kri0006", "Analysis_srs0001")
  dfMetrics <- dplyr::filter(gsm.core::reportingMetrics, .data$MetricID %in% vMetrics)
  dfMetrics <- dfMetrics %>%
    dplyr::filter(.data$MetricID == "Analysis_kri0001") %>%
    dplyr::mutate(MetricID = "Analysis_kri9999", Metric = "Retired Metric", Abbreviation = "RET", Active = FALSE) %>%
    dplyr::bind_rows(dfMetrics, .)
  dfResults <- dplyr::filter(gsm.core::reportingResults, .data$MetricID %in% vMetrics)
  dfResults <- dfResults %>%
    dplyr::filter(.data$MetricID == "Analysis_kri0001", .data$SnapshotDate < max(.data$SnapshotDate)) %>%
    dplyr::mutate(MetricID = "Analysis_kri9999") %>%
    dplyr::bind_rows(dfResults, .)
  dfBounds <- dplyr::filter(gsm.core::reportingBounds, .data$MetricID %in% vMetrics)
  lCharts <- suppressWarnings(MakeCharts(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    dfBounds = dfBounds
  ))

  strOutputDir <- withr::local_tempdir()
  suppressMessages(suppressWarnings(utils::capture.output(Report_KRI(
    lCharts = lCharts,
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    strOutputDir = strOutputDir,
    strOutputFile = "v2.html",
    strInputPath = system.file("report", "Report_KRI_v2.Rmd", package = "gsm.kri")
  ))))

  html <- paste(readLines(file.path(strOutputDir, "v2.html"), warn = FALSE), collapse = "\n")
  vCards <- stringr::str_match_all(html, "<article class=\"v2-card v2-metric[^\"]*\" id=\"kri-(\\w+)\"")[[1]][, 2]
  expect_equal(vCards[length(vCards)], "Analysis_kri9999")
  expect_match(html, "v2-metric inactive collapsed\" id=\"kri-Analysis_kri9999\"", fixed = TRUE)
  expect_equal(
    stringr::str_match_all(html, "gsm-widget Analysis_kri9999 (\\w+)\"")[[1]][, 2],
    "timeSeries"
  )
  expect_match(html, "Not in latest snapshot", fixed = TRUE)
})

# Sites tab ---------------------------------------------------------------

dfMetricsWeighted <- dplyr::mutate(
  dfMetricsV2,
  Flag = c("-2,-1,0,1,2", "-2,-1,0,1,2", NA),
  RiskScoreWeight = c("32,16,0,1,2", "8,6,0,4,8", NA)
)

dfGroupsSites <- dplyr::bind_rows(
  dfGroupsV2,
  tibble::tribble(
    ~GroupID, ~GroupLevel, ~Param, ~Value,
    "A", "Site", "Country", "US",
    "A", "Site", "City", "Boston",
    "A", "Site", "ParticipantCount", "12"
  )
)

test_that("v2_score_bands maps thresholds to flagged score intervals", {
  dfBands <- v2_score_bands("-2,-1,2,3", "-2,-1,0,1,2")
  expect_equal(dfBands$lo, c(-Inf, -2, -1, 2, 3))
  expect_equal(dfBands$hi, c(-2, -1, 2, 3, Inf))
  expect_equal(dfBands$flag, c(-2, -1, 0, 1, 2))

  # Thresholds are sorted but flags are not, as in the kri0013 workflow.
  dfLower <- v2_score_bands("0.9,0.85", "-2,-1,0")
  expect_equal(dfLower$hi, c(0.85, 0.9, Inf))
  expect_equal(dfLower$flag, c(-2, -1, 0))

  expect_null(v2_score_bands(NA, NA))
})

test_that("v2_rate_bands converts score bands to rates at the site denominator", {
  dfBounds <- tibble::tibble(
    Threshold = c(2, 2, 3, 3),
    Denominator = c(10, 20, 10, 20),
    Metric = c(0.5, 0.4, 0.7, 0.6)
  )
  dfBounded <- v2_rate_bands("2,3", "0,1,2", 15, "bounds", dfBounds)
  expect_equal(dfBounded$lo, c(0, 0.45, 0.65))
  expect_equal(dfBounded$hi, c(0.45, 0.65, Inf))
  expect_equal(dfBounded$flag, c(0, 1, 2))

  # Identity on the numerator: a count threshold becomes count / denominator.
  expect_equal(v2_rate_bands("1.5,2.5", "0,1,2", 10, "numerator")$hi, c(0.15, 0.25, Inf))
  # Identity on the rate itself.
  expect_equal(v2_rate_bands("0.9,0.85", "-2,-1,0", 40, "rate")$hi, c(0.85, 0.9, Inf))

  expect_null(v2_rate_bands("2,3", "0,1,2", 15, "bounds", NULL))
})

test_that("v2_chart_bounds reads the latest-snapshot bounds embedded in scatter plots", {
  dfBounds <- tibble::tibble(
    Threshold = c(2, 2),
    Denominator = c(10, 10),
    Metric = c(0.5, 0.9),
    MetricID = "Analysis_kri0001",
    SnapshotDate = c("2025-03-01", "2025-04-01")
  )
  lCharts <- list(Analysis_kri0001 = list(
    scatterPlot = list(x = list(dfBounds = jsonlite::toJSON(dfBounds))),
    barChart = list(x = list())
  ))

  dfOut <- v2_chart_bounds(lCharts)
  expect_equal(nrow(dfOut), 1)
  expect_equal(dfOut$Metric, 0.9)
  expect_equal(dfOut$MetricID, "Analysis_kri0001")
  expect_equal(nrow(v2_chart_bounds(list())), 0)
})

test_that("ReportV2_SiteData ranks sites by risk score and counts new or worse flags", {
  lData <- ReportV2_SiteData(dfResultsV2, dfMetricsWeighted, dfGroupsSites)

  expect_equal(lData$sites$GroupID, c("A", "B", "C"))
  expect_equal(lData$sites$rank, 1:3)
  expect_equal(lData$sites$new_flags, c(2, 1, 0))
  expect_equal(lData$sites$label[1], "Smith")
  expect_equal(lData$sites$country[1], "US")
  expect_equal(lData$sites$enrolled[1], 12)

  dfCells <- lData$cells
  change_of <- function(g, m) dfCells$change[dfCells$GroupID == g & dfCells$MetricID == m]
  expect_equal(change_of("A", "Analysis_kri0001"), "worse")
  expect_equal(change_of("B", "Analysis_kri0001"), "new")
  expect_equal(change_of("B", "Analysis_kri0002"), "better")
  expect_equal(change_of("C", "Analysis_kri0001"), "same")
  expect_equal(dfCells$weight[dfCells$GroupID == "A" & dfCells$MetricID == "Analysis_kri0002"], 6)
  expect_false("Analysis_srs0001" %in% dfCells$MetricID)

  expect_equal(lData$metrics$study_rate[lData$metrics$MetricID == "Analysis_kri0001"], 0.02)
})

test_that("ReportV2_SiteData excludes inactive metrics from site counts (#325)", {
  lData <- ReportV2_SiteData(
    dfResultsV2,
    dplyr::mutate(dfMetricsWeighted, Active = c(FALSE, TRUE, NA)),
    dfGroupsSites
  )

  expect_equal(lData$sites$new_flags[lData$sites$GroupID == "A"], 1)
  expect_equal(lData$sites$red[lData$sites$GroupID == "A"], 0)
  expect_true(lData$metrics$inactive[lData$metrics$MetricID == "Analysis_kri0001"])
})

test_that("ReportV2_SiteData falls back to flag counts without a risk score", {
  dfResults <- dplyr::filter(dfResultsV2, !grepl("srs", .data$MetricID))
  lData <- ReportV2_SiteData(dfResults, dfMetricsWeighted, dfGroupsSites)

  expect_equal(lData$sites$GroupID, c("A", "B", "C"))
  expect_true(all(is.na(lData$sites$srs)))
})

test_that("ReportV2_SitesTab renders a risk-sorted heatmap with new-flag cues", {
  html <- render_html(ReportV2_SitesTab(
    ReportV2_SiteData(dfResultsV2, dfMetricsWeighted, dfGroupsSites)
  ))
  strBody <- sub("(?s).*<tbody>(.*)</tbody>.*", "\\1", html, perl = TRUE)

  vRows <- stringr::str_match_all(strBody, "<tr[^>]*data-site=\"(\\w+)\"")[[1]][, 2]
  expect_equal(vRows, c("A", "B", "C"))
  expect_match(html, "id=\"v2-site-table\"", fixed = TRUE)
  expect_match(html, "id=\"v2-site-panel\"", fixed = TRUE)
  expect_match(html, "id=\"v2-site-data\"", fixed = TRUE)
  for (strFilter in c("all", "red", "flagged", "new")) {
    expect_match(html, paste0("data-filter=\"", strFilter, "\""), fixed = TRUE)
  }

  # New-flag badge next to the site, and thick borders on new or worse cells.
  expect_match(html, "v2-new-badge\"[^>]*>2 new<", perl = TRUE)
  expect_equal(count_matches(strBody, "v2-new-badge"), 2)
  expect_match(strBody, "v2-cell r worse", fixed = TRUE)
  expect_match(strBody, "v2-cell a worse", fixed = TRUE)
  expect_match(strBody, "v2-cell g\"", fixed = TRUE)
  expect_equal(count_matches(strBody, " worse"), 3)
})

test_that("ReportV2_SitesTab leaves inactive metrics out of the heatmap (#325)", {
  html <- render_html(ReportV2_SitesTab(ReportV2_SiteData(
    dfResultsV2,
    dplyr::mutate(dfMetricsWeighted, Active = c(FALSE, TRUE, NA)),
    dfGroupsSites
  )))
  strHead <- sub("(?s).*<thead>(.*)</thead>.*", "\\1", html, perl = TRUE)

  expect_match(strHead, ">SAE<", fixed = TRUE)
  expect_no_match(strHead, ">AE<", fixed = TRUE)
})

test_that("ReportV2_SitesTab gives every KRI column the same width and shows risk as a value", {
  html <- render_html(ReportV2_SitesTab(
    ReportV2_SiteData(dfResultsV2, dfMetricsWeighted, dfGroupsSites)
  ))

  # The site column is sized to its content; the KRI <col>s carry no width, so a
  # fixed-layout table splits the remaining space between them equally.
  expect_equal(count_matches(html, "<col class=\"v2-kri-col\"/>"), 2)
  expect_match(html, "table id=\"v2-site-table\" class=\"v2-heatmap\" style=\"min-width:", fixed = TRUE)
  expect_match(html, "--v2-site-w:[0-9]+px", perl = TRUE)
  # Risk score is a plain value, without the inline bar.
  expect_no_match(html, "v2-mini", fixed = TRUE)
  expect_match(html, "<td class=\"v2-risk-cell\"><span class=\"v2-num\">12.5</span></td>", fixed = TRUE)
})

test_that("ReportV2_SitesTab links cells to KRIs and summarises each KRI column", {
  html <- render_html(ReportV2_SitesTab(
    ReportV2_SiteData(dfResultsV2, dfMetricsWeighted, dfGroupsSites)
  ))
  strHead <- sub("(?s).*<thead>(.*)</thead>.*", "\\1", html, perl = TRUE)
  strBody <- sub("(?s).*<tbody>(.*)</tbody>.*", "\\1", html, perl = TRUE)

  # Each tile knows its KRI, so hovering or clicking it can open that KRI for the site.
  expect_equal(count_matches(strBody, "data-m=\"Analysis_kri0001\""), 3)
  # Sortable KRI headers with a stacked red/amber/green summary across sites.
  expect_equal(count_matches(strHead, "class=\"v2-kri-th\""), 2)
  expect_match(strHead, "data-sort=\"Analysis_kri0001\"", fixed = TRUE)
  expect_match(strHead, "aria-sort=\"none\"", fixed = TRUE)
  expect_match(strHead, "v2-colbar", fixed = TRUE)
  # AE: A red, B amber, C green.
  expect_match(strHead, "Adverse Event Rate: 1 red, 1 amber, 1 green", fixed = TRUE)
  expect_match(strHead, "data-sort=\"risk\"", fixed = TRUE)
})
