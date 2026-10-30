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
  # The header card holds the title, outside the contents list, and the study facts.
  flat <- gsub("\\s+", " ", html)
  expect_match(html, '<header id="rm-header" class="rm-header">', fixed = TRUE)
  expect_match(html, '<h1 class="toc-ignore">Repeat Measurements</h1>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Study</b> STUDY1 </span>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Snapshot</b> 2024-03-01 </span>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Window</b> W = 3 </span>', fixed = TRUE)
  expect_match(html, 'id="rm-how-toggle" type="button" class="rm-btn" aria-expanded="false" aria-controls="rm-how"', fixed = TRUE)
  expect_match(html, '<div id="rm-how" class="rm-how" hidden>', fixed = TRUE)
  expect_false(grepl('class="rm-ctx"', html, fixed = TRUE))
  for (id in c("rm-filter-strip", "rm-chip-country", "rm-chip-site", "rm-chip-subj", "rm-count", "rm-overview", "rm-data")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  # The Vitals filter is a multi-select of every vital, KRI or not.
  for (id in c("rm-vital-btn", "rm-vital-summary", "rm-vital-menu", "rm-vital-all")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  for (v in c("weight", "pulse", "sysbp", "diabp", "resp", "temp", "height")) {
    expect_match(html, paste0('type="checkbox" value="', v, '" data-rm-vital-cb checked'), fixed = TRUE)
  }
  expect_false(grepl("data-rm-group=", html, fixed = TRUE))
  # The overview opens as distribution bars and can switch to counts.
  expect_match(html, 'id="rm-ov-distribution" type="button" data-rm-ov="distribution" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-ov-counts" type="button" data-rm-ov="counts" aria-pressed="false"', fixed = TRUE)
  expect_match(html, "WT 3/8 <span class=\"ok\">= kri0020a", fixed = TRUE)
  expect_match(html, "HR 1/3 <span class=\"ok\">= kri0020b", fixed = TRUE)
  expect_match(html, "W = 3 (from the kri0020 metrics)", fixed = TRUE)
  expect_false(grepl("not in this study's metrics", html, fixed = TRUE))

  data <- rm_DataBlock(html)
  expect_setequal(names(data), c("sites", "siteRule", "vitals", "participants", "settings", "export"))
  expect_equal(data$participants$subjid, c("A", "B", "C", "D", "E"))
  expect_equal(data$participants$invid, c("S1", "S1", "S2", "S3", "S3"))
  expect_true(data$export)
})

test_that("thresholds reach the browser exactly, so R and the browser agree at a boundary (#343, #344)", {
  html <- render_rm(
    lListings = rm_FixtureEdge(),
    dfMetrics = rm_FixtureMetrics(),
    strFlagRule = "rate",
    vFlagThresholds = c(0.5, 2 / 3)
  )
  lData <- rm_DataBlock(html)
  expect_identical(lData$settings$thresholds$rate[2], 2 / 3)
  lTiles <- rm_WidgetPayloads(html)[["rm-tiles"]]$tiles
  lF <- Filter(function(t) t$subjid == "F" && t$vital == "weight", lTiles)
  expect_equal(lF[[1]]$flag, "Red")
  expect_true("(missing)" %in% lData$participants$country)
})

test_that("the strip has reset, settings and contents buttons, and settings default to 2 / 3 repeating windows (#344)", {
  html <- rm_default_html()
  for (id in c("rm-reset", "rm-settings-toggle", "rm-toc-toggle", "rm-settings", "rm-th-amber", "rm-th-red", "rm-min-windows", "rm-settings-defaults", "rm-settings-done")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  # Settings open as a popover dialog from the strip.
  expect_match(html, '<div id="rm-settings" class="rm-settings" role="dialog" aria-label="Report settings" hidden>', fixed = TRUE)
  for (v in c("separate", "combined", "both")) {
    expect_match(html, paste0('data-rm-set="bp" value="', v, '"'), fixed = TRUE)
  }
  expect_match(html, 'data-rm-set="bp" value="separate" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'data-rm-set="rule" value="count" aria-pressed="true"', fixed = TRUE)
  expect_match(gsub("\\s+", " ", html), "repeating windows, Amber \u2265 2, Red \u2265 3; participants need 1 window for a flag", fixed = TRUE)
  settings <- rm_DataBlock(html)$settings
  expect_equal(settings$rule, "count")
  expect_equal(settings$thresholds$count, c(2, 3))
  expect_equal(settings$thresholds$rate, c(0.2, 0.3))
  expect_equal(settings$minWindows, 1)
  expect_equal(settings$bp, "separate")
  # Values are hidden by default.
  expect_false(grepl('id="rm-show-values" checked', html, fixed = TRUE))
})

test_that("flag and blood pressure arguments reach the report settings and paired BP is listed (#343, #344)", {
  f <- rm_Fixture()
  f$Mapped_VS$sysbp <- 120
  f$Mapped_VS$diabp <- 80
  html <- render_rm(
    f,
    dfMetrics = rm_FixtureMetrics(),
    strFlagRule = "rate",
    vFlagThresholds = c(0.1, 0.5),
    nMinWindows = 2,
    strBPMode = "both"
  )
  data <- rm_DataBlock(html)
  expect_equal(data$settings$rule, "rate")
  expect_equal(data$settings$thresholds$rate, c(0.1, 0.5))
  expect_equal(data$settings$thresholds$count, c(2, 3))
  expect_equal(data$settings$minWindows, 2)
  expect_equal(data$settings$bp, "both")
  expect_equal(data$vitals$vital, c("weight", "pulse", "sysbp", "diabp", "bp", "resp", "temp", "height"))
  expect_false(any(c("flagged", "group") %in% names(data$vitals)))
  expect_true(is.na(data$vitals$metric[data$vitals$vital == "bp"]))
  expect_match(gsub("\\s+", " ", html), "% of windows that repeat, Amber \u2265 10%, Red \u2265 50%; participants need 2 windows for a flag", fixed = TRUE)
  expect_match(html, 'data-rm-vital-opt="bp"', fixed = TRUE)
  x <- rm_WidgetPayloads(html)[["rm-tiles"]]
  expect_true("bp" %in% vapply(x$tiles, `[[`, character(1), "vital"))
  expect_true(any(grepl("120/80", unlist(rm_WidgetPayloads(html)[["rm-dt-wide"]]$data), fixed = TRUE)))

  expect_error(Report_RepeatMeasurements(lListings = f, strBPMode = "paired"), "should be one of")
})

test_that("the Site/Country Distribution is one table of flags by measure for each country or site (#345)", {
  html <- rm_default_html()
  # rmFilters.js draws the table; the report has no distribution charts.
  vChartIDs <- unlist(lapply(rm_WidgetPayloads(html), function(x) x$metadata$chartId))
  expect_false(any(grepl("^rm-(study|country|site)", vChartIDs)))
  expect_match(html, "<h2>Site/Country Distribution</h2>", fixed = TRUE)
  expect_false(grepl("Participant distribution", html, fixed = TRUE))
  expect_match(html, '<div id="rm-dist" class="rm-dist-wrap"></div>', fixed = TRUE)
  expect_match(html, 'id="rm-dist-country" type="button" data-rm-dist="level" value="country" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-site" type="button" data-rm-dist="level" value="site" aria-pressed="false"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-participants" type="button" data-rm-dist="unit" value="participants" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-sites" type="button" data-rm-dist="unit" value="sites" aria-pressed="false"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-search"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-tip"', fixed = TRUE)
  data <- rm_DataBlock(html)
  # Site flags: the latest KRI flag for weight and HR, the report's own
  # calculation (here below accrual) for the other vitals.
  dfW <- data$sites[data$sites$vital == "weight", ]
  expect_equal(dfW$invid, c("S1", "S2", "S3"))
  expect_equal(dfW$flag, c(2L, 0L, 1L))
  expect_equal(unique(dfW$source), "KRI")
  dfH <- data$sites[data$sites$vital == "height", ]
  expect_equal(unique(dfH$source), "report")
  expect_true(all(is.na(dfH$flag)))
  expect_equal(data$siteRule$thresholds, c(0.2, 0.3))
  expect_equal(data$siteRule$accrual, 3)
  # rmFilters.js builds the table from the tiles, so every tile carries N, D
  # and its site and country.
  x <- rm_WidgetPayloads(html)[["rm-tiles"]]
  expect_true(all(c("country", "invid", "Numerator", "Denominator", "flag") %in% names(x$tiles[[1]])))
})

test_that("the participant listing is the in-repo tiles widget with label, sort, search and download controls (#347)", {
  html <- rm_default_html()
  x <- rm_WidgetPayloads(html)[["rm-tiles"]]
  expect_false(is.null(x))
  expect_equal(x$label, "both")
  expect_equal(x$pageSize, 50)
  expect_equal(unique(vapply(x$tiles, `[[`, character(1), "subjid")), c("A", "B", "D", "C", "E"))
  expect_match(html, "class=\"Widget_RepeatMeasurementsTiles html-widget", fixed = TRUE)
  expect_match(html, "function renderRepeatMeasurementsTiles", fixed = TRUE)
  expect_false(grepl("gsm.viz-2.5.0", html, fixed = TRUE))
  for (id in c("rm-label-both", "rm-label-rate", "rm-label-nd", "rm-tiles-sort", "rm-tiles-search", "rm-tiles-csv")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  expect_match(html, "Click a participant or tile to filter the report", fixed = TRUE)
})

test_that("the vitals listing is one level and the data table offers Long and Wide (#346)", {
  html <- rm_default_html()
  for (id in c("rm-vitals-view", "rm-vitals", "rm-show-values", "rm-only-repeat", "rm-shape-long", "rm-shape-wide", "rm-dt-only", "rm-dt-long", "rm-dt-wide")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  for (id in c("rm-all-records", "rm-records", "rm-back", "rm-crumb")) {
    expect_false(grepl(paste0('id="', id, '"'), html, fixed = TRUE), label = id)
  }
  expect_match(html, 'data-rm-shape="wide" aria-pressed="true"', fixed = TRUE)
  lPayloads <- rm_WidgetPayloads(html)
  expect_equal(length(lPayloads[["rm-vitals"]]$data[[1]]), 35)
  dfVS <- rm_Fixture()$Mapped_VS
  expect_equal(length(lPayloads[["rm-dt-wide"]]$data[[1]]), nrow(dfVS))
  expect_equal(
    length(lPayloads[["rm-dt-long"]]$data[[1]]),
    sum(!is.na(unlist(dfVS[c("weight", "pulse", "height")])))
  )
  for (id in c("rm-vitals", "rm-dt-long", "rm-dt-wide")) {
    expect_equal(lPayloads[[id]]$options$buttons[[1]]$extend, "csv", label = id)
  }
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
  expect_match(gsub("\\s+", " ", html), "W = 3 (default) and flags sites at Amber \u2265 20%, Red \u2265 30% of windows, with at least 3 windows.", fixed = TRUE)

  # No participant has 7 measurements of a vital.
  html <- render_rm(nWindowLength = 7)
  expect_match(gsub("\\s+", " ", html), "none has the 7 measurements of a vital needed for 1 window of 7.", fixed = TRUE)
  expect_match(html, "W = 7 (report argument)", fixed = TRUE)
  # The minimum windows add to the measurements needed (W + 5 - 1).
  html <- render_rm(nMinWindows = 5)
  expect_match(gsub("\\s+", " ", html), "none has the 7 measurements of a vital needed for 5 windows of 3.", fixed = TRUE)
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
      "2. Choose vitals in the Vitals menu. In the Site/Country Distribution, switch Rows between Country and Site, then click a country row and a site row.",
      "3. In the Participant Listing, switch the cell label, then click a participant or tile.",
      "4. In the Vitals Listing and the Data table, click a row; click it again to clear. Switch the Data table between Long and Wide.",
      sep = "\n"
    ),
    chrChecks = c(
      "The Study row of the Site/Country Distribution matches the Study overview for each measure.",
      "Filters apply to every section except the Study overview, and the floating filter strip shows what is selected and how many participants are in scope.",
      "Selecting a participant in any listing filters the Vitals Listing and the Data table to that participant.",
      "Repeated values are highlighted in the Vitals Listing and both Data table shapes.",
      "The Participant Listing, Vitals Listing and Data table can be downloaded as CSV."
    )
  )
})
