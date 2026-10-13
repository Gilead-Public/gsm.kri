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

test_that("ReportV2_Takeaways names the riskiest metric and top risk-score sites", {
  html <- render_html(ReportV2_Takeaways(
    ReportV2_Summary(dfResultsV2), dfResultsV2, dfMetricsV2, dfGroupsV2
  ))

  expect_match(html, "Adverse Event Rate", fixed = TRUE)
  expect_match(html, "Highest site risk scores", fixed = TRUE)
  expect_match(html, "data-site=\"A\"", fixed = TRUE)
  expect_match(html, "Smith", fixed = TRUE)
})

test_that("ReportV2_Takeaways skips risk-score list when no SRS metric exists", {
  dfResults <- dplyr::filter(dfResultsV2, !grepl("srs", .data$MetricID))
  html <- render_html(ReportV2_Takeaways(
    ReportV2_Summary(dfResults), dfResults, dfMetricsV2, dfGroupsV2
  ))

  expect_no_match(html, "Highest site risk scores")
})

test_that("ReportV2_Nav links every KRI with flag badges and excludes SRS", {
  html <- render_html(ReportV2_Nav(dfResultsV2, dfMetricsV2))

  expect_match(html, "href=\"#kri-Analysis_kri0001\"", fixed = TRUE)
  expect_match(html, "href=\"#kri-Analysis_kri0002\"", fixed = TRUE)
  expect_no_match(html, "Analysis_srs0001")
  expect_match(html, "v2-badge red\">1<", fixed = TRUE)
  expect_match(html, "href=\"#v2-changes\"", fixed = TRUE)
})

test_that("ReportV2_FlagChanges groups changed flags into categories", {
  html <- render_html(ReportV2_FlagChanges(dfResultsV2, dfMetricsV2, dfGroupsV2))

  expect_match(html, "data-cat=\"escalated\"", fixed = TRUE)
  expect_match(html, "data-cat=\"improved\"", fixed = TRUE)
  expect_match(html, "data-cat=\"new\"", fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr("class=\"v2-change\"", html))), 4)
  expect_match(html, "Serious Adverse Event Rate", fixed = TRUE)
  expect_match(html, "A (Smith)", fixed = TRUE)
  expect_no_match(html, "Analysis_srs0001")
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
  lCharts <- MakeCharts(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = gsm.core::reportingGroups,
    dfBounds = dfBounds
  )
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
})
