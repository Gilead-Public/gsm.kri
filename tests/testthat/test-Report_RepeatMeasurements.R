# Each render takes several seconds, so share the default render across tests.
rm_default_html <- local({
  html <- NULL
  function() {
    if (is.null(html)) {
      html <<- render_rm(
        dfResults = rm_FixtureResults(),
        dfMetrics = rm_FixtureMetrics()
      )
    }
    html
  }
})

test_that("Report_RepeatMeasurements renders the filter strip and study overview (#344)", {
  html <- rm_default_html()
  expect_match(html, "<h1>Repeat Measurements</h1>", fixed = TRUE)
  expect_match(html, "<strong>Study:</strong> STUDY1", fixed = TRUE)
  expect_match(html, "Snapshot date: 2024-03-01", fixed = TRUE)
  for (id in c("rm-filter-strip", "rm-chip-country", "rm-chip-site", "rm-chip-subj", "rm-overview", "rm-data")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  for (g in c("All", "Weight", "HR", "BP", "RR", "Temp")) {
    expect_match(html, paste0('data-rm-group="', g, '"'), fixed = TRUE)
  }
  expect_match(html, "WT 3/8 <span class=\"ok\">= kri0020a", fixed = TRUE)
  expect_match(html, "HR 1/3 <span class=\"ok\">= kri0020b", fixed = TRUE)
  expect_match(html, "W = 3 (from the kri0020 metrics)", fixed = TRUE)
  expect_false(grepl("not in this study's metrics", html, fixed = TRUE))

  data <- rm_DataBlock(html)
  expect_setequal(names(data), c("overview", "distribution", "siteFlags", "vitals", "groups", "export"))
  study <- data$overview[data$overview$Level == "study" & data$overview$vital == "weight", ]
  expect_equal(c(study$enrolled, study$evaluable, study$amber, study$red), c(5, 3, 1, 1))
  expect_true(data$export)
})

test_that("the report shows each vital's flag distribution by study, country and site (#345)", {
  html <- rm_default_html()
  vChartIDs <- vapply(
    Filter(function(x) !is.null(x$metadata$chartId), rm_WidgetPayloads(html)),
    function(x) x$metadata$chartId,
    character(1)
  )
  vVitals <- c("weight", "pulse", "sysbp", "diabp", "resp", "temp")
  expect_true(all(
    c("rm-study", paste0("rm-country-", vVitals), paste0("rm-site-", vVitals)) %in% vChartIDs
  ))
  for (strVital in vVitals) {
    expect_match(html, paste0('data-rm-vital="', strVital, '"'), fixed = TRUE)
  }
  data <- rm_DataBlock(html)
  expect_equal(data$siteFlags$weight, list(S1 = -2L, S2 = 0L, S3 = 1L))
  site <- data$distribution$site
  expect_equal(sum(site$n[site$vital == "weight"]), 3)
})

test_that("the participant listing is a tiles chart with label, sort, search and download controls (#347)", {
  html <- rm_default_html()
  tiles <- Filter(function(x) identical(x$metadata$chartId, "rm-tiles"), rm_WidgetPayloads(html))
  expect_length(tiles, 1)
  expect_equal(tiles[[1]]$spec$mapping$label, "label_both")
  expect_equal(tiles[[1]]$spec$rows$pageSize, 50)
  expect_equal(unique(unlist(tiles[[1]]$data$subjid)), c("A", "B", "D", "C", "E"))
  for (id in c("rm-label-both", "rm-label-rate", "rm-label-nd", "rm-tiles-sort", "rm-tiles-search", "rm-tiles-csv")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
})

test_that("the vitals listing drills from one row per vital into the visit records (#346)", {
  html <- rm_default_html()
  for (id in c("rm-vitals-view", "rm-vitals", "rm-show-values", "rm-only-repeat", "rm-all-records", "rm-records-view", "rm-records", "rm-back", "rm-crumb")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  dt <- Filter(function(x) !is.null(x$options$columnDefs), rm_WidgetPayloads(html))
  expect_length(dt, 2)
  expect_equal(length(dt[[1]]$data[[1]]), 35)
  expect_equal(dt[[1]]$options$buttons[[1]]$extend, "csv")
})

test_that("turning off export removes every download control (#346, #347)", {
  html <- render_rm(dfMetrics = rm_FixtureMetrics(), bExport = FALSE)
  expect_false(grepl('id="rm-tiles-csv"', html, fixed = TRUE))
  expect_false(grepl('"extend":"csv"', html, fixed = TRUE))
  expect_false(rm_DataBlock(html)$export)
  expect_match(html, "No <code>kri0020</code> results to reconcile with.", fixed = TRUE)
})

test_that("the report explains missing vital signs and a study without the repeat-measure KRIs (#344)", {
  f <- rm_Fixture()
  html <- render_rm(rm_listings(f$Mapped_VS[0, ], f$Mapped_SUBJ))
  expect_match(html, "No vital signs recorded.", fixed = TRUE)
  expect_match(html, "not in this study", fixed = TRUE)
  expect_match(html, "W = 3 (default)", fixed = TRUE)

  # No participant has 7 measurements of a vital.
  html <- render_rm(nWindowLength = 7)
  expect_match(html, "No evaluable participants.", fixed = TRUE)
  expect_match(html, "W = 7 (report argument)", fixed = TRUE)
})

test_that("Report_RepeatMeasurements requires subject listings (#344)", {
  expect_error(Report_RepeatMeasurements(lListings = NULL), "Mapped_SUBJ")
  expect_error(
    Report_RepeatMeasurements(lListings = list(Mapped_VS = data.frame())),
    "Mapped_SUBJ"
  )
})

test_that("Repeat Measurements report example is accepted by a user (#348)", {
  skip_if_not_installed("qcthat")
  # gh shows a pagination progress bar while qcthat looks up the issue.
  withr::local_options(cli.progress_show_after = Inf, cli.progress_handlers = character())
  qcthat::ExpectUserAccepts(
    "The Repeat Measurements report lets a reviewer find participants and sites with repeated vital-sign values.",
    intIssue = 348,
    chrInstructions = paste(
      "1. Navigate to the [Repeat Measurements report example](https://gilead-public.github.io/gsm.kri/dev/examples/Example_RepeatMeasurements.html).",
      "2. Use the vital-group buttons, then click a country bar and a site bar.",
      "3. In the Participant Listing, switch the cell label and click a participant.",
      "4. In the Vitals Listing, show values, then click a row to open its records and go back.",
      sep = "\n"
    ),
    chrChecks = c(
      "The overview counts match the distribution charts for each vital.",
      "Filters apply to every section, and the filter strip shows what is selected.",
      "Selecting a participant filters the Vitals Listing to that participant.",
      "Repeated values are highlighted in the Vitals Listing and the records.",
      "The Participant Listing and Vitals Listing can be downloaded as CSV."
    )
  )
})
