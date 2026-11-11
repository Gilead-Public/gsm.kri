# Each render takes several seconds, so share the default render across tests.
rep_default_html <- local({
  html <- NULL
  function() {
    if (is.null(html)) {
      html <<- render_rm(
        dfResults = rep_FixtureResults(),
        dfMetrics = rep_FixtureMetrics()
      )
    }
    html
  }
})

test_that("Report_RepeatMeasurements renders the filter strip and study overview (#344)", {
  html <- rep_default_html()
  # The header card holds the title, outside the contents list, and the study facts.
  flat <- gsub("\\s+", " ", html)
  expect_match(html, '<header id="rm-header" class="rm-header">', fixed = TRUE)
  expect_match(html, '<h1 class="toc-ignore">Repeat Measurements</h1>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Study</b> STUDY1 </span>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Snapshot</b> 2024-03-01 </span>', fixed = TRUE)
  expect_match(flat, '<span class="rm-pill"> <b>Window</b> 3 measurements </span>', fixed = TRUE)
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
  expect_false(grepl("rm-recon", html, fixed = TRUE))
  expect_false(grepl("W = 3", html, fixed = TRUE))
  expect_false(grepl("not in this study's metrics", html, fixed = TRUE))

  data <- rep_DataBlock(html)
  expect_setequal(names(data), c("sites", "siteRule", "vitals", "participants", "settings", "export"))
  expect_equal(data$participants$subjid, c("A", "B", "C", "D", "E"))
  expect_equal(data$participants$invid, c("S1", "S1", "S2", "S3", "S3"))
  expect_true(data$export)
})

test_that("thresholds reach the browser exactly, so R and the browser agree at a boundary (#343, #344)", {
  html <- render_rm(
    lListings = rep_FixtureEdge(),
    dfMetrics = rep_FixtureMetrics(),
    strFlagRule = "rate",
    vFlagThresholds = c(0.5, 2 / 3)
  )
  lData <- rep_DataBlock(html)
  expect_identical(lData$settings$thresholds$rate[2], 2 / 3)
  lTiles <- rep_WidgetPayloads(html)[["rm-tiles"]]$tiles
  lF <- Filter(function(t) t$subjid == "F" && t$vital == "weight", lTiles)
  expect_equal(lF[[1]]$flag, "Red")
  expect_true("(missing)" %in% lData$participants$country)
})

test_that("a site that spans countries is noted, and each participant keeps their own country (#344)", {
  html <- render_rm(lListings = rep_FixtureSplit(), dfMetrics = rep_FixtureMetrics())
  expect_match(
    gsub("\\s+", " ", html),
    "1 site with participants in more than one country</strong> (S2). As in the country KRIs, each participant counts toward their own country, so the site is counted in each of its countries.",
    fixed = TRUE
  )
  lData <- rep_DataBlock(html)
  expect_equal(lData$participants$country, c("US", "US", "JP"))
  expect_equal(sum(lData$sites$invid == "S2" & lData$sites$vital == "weight"), 1)
  expect_false(grepl("more than one country", rep_default_html(), fixed = TRUE))
})

test_that("the strip has reset, settings and contents buttons, and settings default to 2 / 3 repeating windows (#344)", {
  html <- rep_default_html()
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
  settings <- rep_DataBlock(html)$settings
  expect_equal(settings$rule, "count")
  expect_equal(settings$thresholds$count, c(2, 3))
  expect_equal(settings$thresholds$rate, c(0.2, 0.3))
  expect_equal(settings$minWindows, 1)
  expect_equal(settings$bp, "separate")
  # Values are hidden by default.
  expect_false(grepl('id="rm-show-values" checked', html, fixed = TRUE))
})

test_that("flag and blood pressure arguments reach the report settings and paired BP is listed (#343, #344)", {
  f <- rep_Fixture()
  f$Mapped_VS$sysbp <- 120
  f$Mapped_VS$diabp <- 80
  html <- render_rm(
    f,
    dfMetrics = rep_FixtureMetrics(),
    strFlagRule = "rate",
    vFlagThresholds = c(0.1, 0.5),
    nMinWindows = 2,
    strBPMode = "both"
  )
  data <- rep_DataBlock(html)
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
  x <- rep_WidgetPayloads(html)[["rm-tiles"]]
  expect_true("bp" %in% vapply(x$tiles, `[[`, character(1), "vital"))
  expect_true(any(grepl("120/80", unlist(rep_WidgetPayloads(html)[["rm-dt-wide"]]$data), fixed = TRUE)))

  expect_error(Report_RepeatMeasurements(lListings = f, strBPMode = "paired"), "should be one of")
})

test_that("the Site/country distribution is one table of flags by measure for each country or site (#345)", {
  html <- rep_default_html()
  # rmFilters.js draws the table; the report has no distribution charts.
  vChartIDs <- unlist(lapply(rep_WidgetPayloads(html), function(x) x$metadata$chartId))
  expect_false(any(grepl("^rm-(study|country|site)", vChartIDs)))
  expect_match(html, "<h2>Site/country distribution</h2>", fixed = TRUE)
  expect_false(grepl("Participant distribution", html, fixed = TRUE))
  expect_match(html, '<div id="rm-dist" class="rm-dist-wrap"></div>', fixed = TRUE)
  expect_match(html, 'id="rm-dist-country" type="button" data-rm-dist="level" value="country" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-site" type="button" data-rm-dist="level" value="site" aria-pressed="false"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-participants" type="button" data-rm-dist="unit" value="participants" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-sites" type="button" data-rm-dist="unit" value="sites" aria-pressed="false"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-search"', fixed = TRUE)
  expect_match(html, 'id="rm-dist-tip"', fixed = TRUE)
  data <- rep_DataBlock(html)
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
  x <- rep_WidgetPayloads(html)[["rm-tiles"]]
  expect_true(all(c("country", "invid", "Numerator", "Denominator", "flag") %in% names(x$tiles[[1]])))
})

test_that("the participant listing is the in-repo tiles widget with label, sort, search and download controls (#347)", {
  html <- rep_default_html()
  x <- rep_WidgetPayloads(html)[["rm-tiles"]]
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

test_that("the measure listing is one level and the data table offers Wide and a browser-built Long (#346)", {
  html <- rep_default_html()
  for (id in c("rm-vitals-view", "rm-vitals", "rm-show-values", "rm-only-repeat", "rm-shape-long", "rm-shape-wide", "rm-dt-only", "rm-dt-missing", "rm-dt-long", "rm-dt-wide")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  for (id in c("rm-all-records", "rm-records", "rm-back", "rm-crumb")) {
    expect_false(grepl(paste0('id="', id, '"'), html, fixed = TRUE), label = id)
  }
  expect_match(html, 'data-rm-shape="wide" aria-pressed="true"', fixed = TRUE)
  expect_match(html, "<h2>Measure listing</h2>", fixed = TRUE)
  expect_match(html, "<h2>Participant listing</h2>", fixed = TRUE)
  # Wide comes first; rmFilters.js builds Long from the Wide data on first use.
  expect_lt(regexpr('id="rm-shape-wide"', html), regexpr('id="rm-shape-long"', html))
  lPayloads <- rep_WidgetPayloads(html)
  expect_equal(length(lPayloads[["rm-vitals"]]$data[[1]]), 35)
  dfVS <- rep_Fixture()$Mapped_VS
  expect_equal(length(lPayloads[["rm-dt-wide"]]$data[[1]]), nrow(dfVS))
  expect_null(lPayloads[["rm-dt-long"]])
  for (id in c("rm-vitals", "rm-dt-wide")) {
    expect_equal(lPayloads[[id]]$options$buttons[[1]]$extend, "csv", label = id)
  }
})

test_that("turning off export removes every download control (#346, #347)", {
  html <- render_rm(dfMetrics = rep_FixtureMetrics(), bExport = FALSE)
  expect_false(grepl('id="rm-tiles-csv"', html, fixed = TRUE))
  expect_false(grepl('"extend":"csv"', html, fixed = TRUE))
  expect_false(rep_DataBlock(html)$export)
})

test_that("the report explains missing vital signs and a study without the repeat-measure KRIs (#344)", {
  f <- rep_Fixture()
  html <- render_rm(rep_listings(f$Mapped_VS[0, ], f$Mapped_SUBJ))
  expect_match(html, "No vital signs recorded.", fixed = TRUE)
  expect_match(html, "not in this study", fixed = TRUE)
  expect_match(gsub("\\s+", " ", html), "a window of 3 measurements (default) and flags sites at Amber \u2265 20%, Red \u2265 30% of windows, with at least 3 windows.", fixed = TRUE)

  # No participant has 7 measurements of a measure.
  html <- render_rm(nWindowLength = 7)
  expect_match(gsub("\\s+", " ", html), "none has the 7 measurements of a measure needed for 1 window of 7.", fixed = TRUE)
  expect_match(gsub("\\s+", " ", html), "a window of 7 measurements (report argument)", fixed = TRUE)
  # The minimum windows add to the measurements needed (W + 5 - 1).
  html <- render_rm(nMinWindows = 5)
  expect_match(gsub("\\s+", " ", html), "none has the 7 measurements of a measure needed for 5 windows of 3.", fixed = TRUE)
})

test_that("Report_RepeatMeasurements requires subject listings (#344)", {
  expect_error(Report_RepeatMeasurements(lListings = NULL), "Mapped_SUBJ")
  expect_error(
    Report_RepeatMeasurements(lListings = list(Mapped_VS = data.frame())),
    "Mapped_SUBJ"
  )
})

# UAT checks mirror section 3 of the UAT plan: one ExpectUserAccepts per
# requirement, with stable participants and sites from the fixed example data.
rm_uat_instructions <- c(
  "1. Open the [Repeat Measurements example report](https://gilead-public.github.io/gsm.kri/pr/349/dev/examples/Example_RepeatMeasurements.html) in Chrome or Edge.",
  "2. **Reload the page before you start**, and wherever a check says \"Reload\", so that you start with no filters and the default settings.",
  "3. The **bar** is the strip at the top of the report that holds **Measures**, the filter chips, \"*N* / 754 participants selected\", **Reset filters**, **Settings** and **Hide contents**. It stays on screen as you scroll.",
  "4. Measures are shown by their short codes in some places: WT (Weight), HR (Heart rate), SBP, DBP, RR (Respiratory rate), Temp, Ht (Height), BSA, and BP (Blood pressure (SBP/DBP)).",
  "5. A **window** is 3 consecutive measurements of one measure for one participant. A run of *k* identical consecutive values contains *k* − 2 repeating windows; for example, 5 identical values in a row are 3 repeating windows.",
  "6. The participants, sites and numbers named in the checks come from the fixed example data, so they are the same in every build. Only the **Snapshot** date changes."
)

ExpectRMUserAccepts <- function(strDescription, intIssue, chrChecks) {
  skip_if_not_installed("qcthat")
  # gh shows a pagination progress bar while qcthat looks up the issue.
  withr::local_options(cli.progress_show_after = Inf, cli.progress_handlers = character())
  qcthat::ExpectUserAccepts(
    strDescription,
    intIssue = intIssue,
    chrInstructions = paste(
      c(rm_uat_instructions, paste0(length(rm_uat_instructions) + 1, ". Work through the checks in order. Tick a check only when every part of it is true.")),
      collapse = "\n"
    ),
    chrChecks = chrChecks
  )
}

test_that("Repeat Measurements overall report, filters and drill-down is accepted by a user (#344)", {
  ExpectRMUserAccepts(
    "The Repeat Measurements report's header, filters, settings and drill-down work as described.",
    intIssue = 344,
    chrChecks = c(
      "A1. Confirm that the header shows **Study** AA-AA-000-0000, a **Snapshot** date (in the example, the date the page was built), **Window** \"3 measurements\", and a **Participant flag** line reading \"repeating windows, Amber ≥ 2, Red ≥ 3; participants need 1 window for a flag\".",
      "A2. Confirm that clicking **How to read** shows an explanation of windows, flags, Settings and filters, and that clicking it again hides the explanation.",
      "A3. Click **Measures** in the bar. Confirm that a **KRI** badge appears beside Weight, Heart rate, Systolic BP, Diastolic BP, Respiratory rate and Temperature, and that no badge appears beside Height or BSA. Press Esc to close the menu.",
      "A4. In **Measures**, clear **All measures** and tick only **Weight**, then press Esc. Confirm that the Measures button shows **WT**; that Site/country distribution, Participant listing, Measure listing and Data table show only Weight; and that the Study overview still shows every measure. Tick Heart rate as well, and confirm that the button shows **WT, HR**. Tick **All measures**, and confirm that it shows **All**.",
      "A5. Reload. In the **Study overview**, click **Weight**. Confirm that the Measures button shows **WT** and that the sections below show only Weight. Click Weight again, and confirm that the button shows **All** and every measure is shown again.",
      "A6. Reload. Hover over the Weight bar in the Study overview and note the counts (Not flagged 645, Amber 37, Red 72). In **Site/country distribution**, click the **UK** row. Confirm that the Study overview Weight counts have not changed.",
      "A7. Continuing from A6, set **Rows** to **Site**, click site **0X7893**, then click participant **S18479** in the **Participant listing**. Confirm that the bar shows a Country, a Site and a Participant chip and \"1 / 754 participants selected\". Click the × on the Participant chip, and confirm that only that chip is removed. Click **Reset filters**, and confirm that every chip is removed and that Rows is still **Site**.",
      "A8. Reload. In **Measures**, tick only Weight and Heart rate, then click participant **S10333** in the Participant listing. Confirm that the Measure listing and Data table show only S10333, and that the Measures button still shows WT, HR. Click S10333 again, and confirm that the previous view returns.",
      "A9. Reload. In Site/country distribution, keep Rows = **Country**, set Cells to **Site flags**, and write down the values in the **UK** row (you need them in A10). In the Participant listing, confirm that **S10333**'s Heart rate tile is Amber, 2/6. Open **Settings**, set **Red ≥** to 2, and press Tab or **Done** (the change applies when you leave the box). Confirm that S10333's Heart rate tile turns Red, that the header's Participant flag line says \"Red ≥ 2\", and that S10333's Heart rate row in the Measure listing shows \"Red · 33%\".",
      "A10. Continuing from A9, confirm that the UK row's Site flags values are the same as the values you wrote down, because participant flag settings do not affect site flags. Open Settings and click **Restore defaults**. Confirm that S10333's Heart rate tile is Amber again and that the header says \"Red ≥ 3\".",
      "A11. In **Settings**, under **Participant flag**, click **% repeating**. Confirm that the header's Participant flag line changes to \"% of windows that repeat, Amber ≥ 20%, Red ≥ 30%; participants need 1 window for a flag\", and that some participant tiles change colour. Click **# repeating** to return.",
      "A12. In **Settings › Blood pressure**, click **Combined**. Confirm that \"Blood pressure (SBP/DBP)\" replaces Systolic BP and Diastolic BP in the Measures menu, Site/country distribution and Measure listing, and that tile and Data table (Wide) headers show **BP**. Click **Both** (in Settings), and confirm that BP, SBP and DBP are all shown. Click **Separate** to return.",
      "A13. Reload. Using only the keyboard, confirm that Tab reaches each control in the bar and in Settings with a visible focus ring (from Settings, Tab may pass **Hide contents** before entering the dialog), that Enter or Space activates the focused control, and that Esc closes Settings.",
      "A14. Reload. In the Study overview, click **Weight**. In Site/country distribution, set Rows to **Site** and click site **0X7893**. In the Participant listing, click **S18479**'s Weight tile (Red, 3/6). In the Measure listing, tick **Show values**. Confirm that **Measurements in order** shows 68.7 five times in a row in dark red, then 73, 44.7 and 47.8; that five identical values make 3 repeating windows, matching the tile's 3/6; and that the Data table shows the same 8 values in both Wide and Long.",
      "A15. Read **How to read** and each section's description. Confirm that they match what you see, and that you could explain why S18479 is Red for Weight in A14 without help from the developer. Note anything unclear in a comment on the UAT issue."
    )
  )
})

test_that("Repeat Measurements Site/country distribution is accepted by a user (#345)", {
  ExpectRMUserAccepts(
    "The Site/country distribution shows correct flags and filters the report.",
    intIssue = 345,
    chrChecks = c(
      "B1. Hover over the Weight bar in the Study overview and over the Weight cell in the distribution's **Study** row. Confirm that both show Not flagged 645 (86%), Amber 37 (5%), Red 72 (10%) of 754.",
      "B2. Set Rows to **Site**. Hover over site **0X094**'s Weight cell, and confirm that the tooltip reads \"Site flag: Amber · 6 of 23 windows repeating (26%)\". For site **0X4352**, confirm that the Weight, Heart rate, Systolic BP and Diastolic BP dots are Red and that Respiratory rate and Temperature are Green. Open the [Site Report example](https://gilead-public.github.io/gsm.kri/pr/349/dev/examples/Example_SiteReport.html) in another tab. In its **Site Overview** table, set **Site Subset** to **All**. Confirm that in columns RMW, RMHR, RMSBP, RMDBP, RMRR and RMT, 0X094 is Amber for RMW and RMT and Green for the rest, and 0X4352 is Red, Red, Red, Red, Green, Green, matching the report.",
      "B3. Switch **Rows** between **Country** and **Site**, and confirm that the table shows 3 country rows or 141 site rows. With Rows = Site, click **Any flag**, and confirm that only rows whose bar has an Amber or Red segment remain (131 sites). Click **Red only**, and confirm that only rows with a Red segment remain (125 sites).",
      "B4. Reload. Click the **UK** row. Confirm that a Country chip \"UK\" appears, that the bar shows \"189 / 754 participants selected\", and that the other sections show only UK participants. Reload, set Rows to Site, and click site **0X7893**. Confirm that a Site chip appears, that **no** Country chip is added, and that 9 participants are selected. Click the row again, and confirm that the filter is removed.",
      "B5. Click a measure's column header, and confirm that the rows sort by that column; click it again, and confirm that the order reverses. Hover over the UK Weight bar, and confirm that the tooltip shows \"Evaluable: 189 / 189\" and the number and share flagged."
    )
  )
})

test_that("Repeat Measurements Participant listing is accepted by a user (#347)", {
  ExpectRMUserAccepts(
    "The Participant listing shows correct participant flags, sorts and downloads.",
    intIssue = 347,
    chrChecks = c(
      "C1. Find **S10333** (type it in the Participant listing search box). Hover over its tiles, and confirm that each tooltip reads like \"Heart rate: Amber · 2 of 6 windows repeat (33%)\", and that Weight is Green 0/6, Heart rate Amber 2/6 and Systolic BP Red 6/6. Click each of these three tiles in turn (click again to clear). Each time, hover over the flag in that measure's Measure listing row, and confirm that it shows the same colour and \"N *x* of D *y* windows repeating\" with the same numbers.",
      "C2. Open Settings, set **Minimum windows** to 6, and close Settings. Set **Sort** to Participant. Confirm that **S10637**'s Weight tile (0/5 windows) shows **NE** (not evaluable). Click **Restore defaults** in Settings.",
      "C3. Click **Both**, **Rate** and **N/D**, and confirm that the tile labels change to show both values, the rate only, or N/D only.",
      "C4. In **Sort**, choose Worst flag, Participant, Site and Weight rate in turn. Confirm that the participants are re-ordered as each option describes (Worst flag: Red participants first; Participant and Site sort as text, so S089 comes before S10051).",
      "C5. Set Rows to Site, click site **0X7893**, then click **Download CSV** in the Participant listing. Confirm that the file has one row per participant per measure (72 rows for the 9 participants) and that S18479's Weight row shows a Red flag, Numerator 3, Denominator 6 and a rate of 0.5, as on screen."
    )
  )
})

test_that("Repeat Measurements Measure listing and Data table is accepted by a user (#346)", {
  ExpectRMUserAccepts(
    "The Measure listing and Data table show each participant's values and repeating windows.",
    intIssue = 346,
    chrChecks = c(
      "D1. Follow the A14 steps to reach S18479's Weight row. Confirm that the values in **Measurements in order** match the Data table (**Long**) for S18479 Weight, in the same order, and that the dark-red blocks are runs of at least 3 identical consecutive values.",
      "D2. For the same row, confirm that **Distinct** shows 4 / 8: four different values out of eight non-missing values in the Data table.",
      "D3. Reload. Hover over a flag in the Measure listing, and confirm that the tooltip shows the number of values measured and \"*N* of *D* windows repeating\". **Only rows with a repeating window** is ticked by default: untick it, and confirm that the entry count rises from 1,720 to 6,032. Tick it again, and confirm that every row has at least one dark-red block.",
      "D4. With **Wide** selected, type **S28340** in the Data table's Search box. Confirm that there is one row per visit and one column per measure (WT, HR, SBP, DBP, RR, Temp, Ht, BSA), that values in a repeating window are dark red, and that the **Follow-up** row, where no measure was recorded, is grey.",
      "D5. Click **Long**, and confirm that there is one row per non-missing value, in measurement order with a # position, and that the same values are dark red as in Wide.",
      "D6. In **Wide**, with S28340 still in the Search box, untick **Show visits with all measures missing**, and confirm that S28340 drops from 8 rows to 7 (the grey Follow-up row disappears); tick it again to restore it. Clear the search. **Only participants with a repeating window** is ticked by default: confirm that every remaining participant has at least one dark-red value. Click **Long**, and confirm that the checkbox now reads **Only measures with a repeating window** and that **Show visits with all measures missing** is greyed out.",
      "D7. Reload. Set Rows to Site and click site **0X7893**. Click **Download CSV** under the Measure listing, and under the Data table in Wide and in Long. Confirm that each file's row count equals the entry count shown under its table (22, 64 and 171), and that S18479's Weight values match the screen."
    )
  )
})

test_that("strContext is shown above the title", {
  html <- render_rm(
    dfMetrics = rep_FixtureMetrics(),
    strContext = '<a href="study.html">Back to STUDY1</a>'
  )
  flat <- gsub("\\s+", " ", html)
  expect_match(
    flat,
    '<div class="rm-ctx"><a href="study.html">Back to STUDY1</a></div> <div class="rm-title"> <h1 class="toc-ignore">Repeat Measurements</h1>',
    fixed = TRUE
  )
  expect_error(
    Report_RepeatMeasurements(lListings = rep_Fixture(), strContext = NA_character_),
    "strContext"
  )
})

test_that("strContext must be a single character string", {
  for (bad in list(NA_character_, 1, c("<b>a</b>", "<b>b</b>"), NULL)) {
    expect_error(
      Report_RepeatMeasurements(lListings = rep_Fixture(), strContext = bad),
      "strContext must be a single character string"
    )
  }
})

test_that("the header has no Study pill when Mapped_SUBJ has no study ID (#344)", {
  lListings <- rep_Fixture()
  lListings$Mapped_SUBJ$studyid <- NULL
  html <- render_rm(lListings)
  expect_no_match(html, "<b>Study</b>", fixed = TRUE)
  expect_match(gsub("\\s+", " ", html), "<b>Window</b> 3 measurements", fixed = TRUE)

  lListings$Mapped_SUBJ$studyid <- c(NA, "", NA, NA, NA)
  html <- render_rm(lListings)
  expect_no_match(html, "<b>Study</b>", fixed = TRUE)
})

test_that("the report renders with no enrolled participants (#344)", {
  f <- rep_Fixture()
  html <- render_rm(rep_listings(f$Mapped_VS, f$Mapped_SUBJ[0, ]))
  expect_match(html, "No enrolled participants", fixed = TRUE)
  expect_no_match(html, "<b>Study</b>", fixed = TRUE)
  # Every section is skipped, so no widget or data block is embedded.
  expect_no_match(html, 'id="rm-data"', fixed = TRUE)
  expect_no_match(html, 'id="rm-tiles"', fixed = TRUE)
  # Nor are the Measures and Settings controls, which act on that data (#349).
  expect_no_match(html, 'id="rm-vital-btn"', fixed = TRUE)
  expect_no_match(html, 'id="rm-settings"', fixed = TRUE)
})

test_that("the report renders with no enrolled participants and no studyid column (#344)", {
  f <- rep_Fixture()
  dfSubj <- f$Mapped_SUBJ[0, setdiff(names(f$Mapped_SUBJ), "studyid")]
  html <- render_rm(rep_listings(f$Mapped_VS, dfSubj))
  expect_match(html, "No enrolled participants", fixed = TRUE)
  expect_no_match(html, "<b>Study</b>", fixed = TRUE)
})

test_that("IDs with HTML are escaped in the data block and the split-site banner (#344)", {
  html <- render_rm(rep_FixtureHTML(), dfMetrics = rep_FixtureMetrics())
  strData <- sub('.*<script type="application/json" id="rm-data">(.*?)</script>.*', "\\1", html)
  expect_match(strData, '"subjid":"\\u003c\\/script>\\u003cb>x"', fixed = TRUE)
  expect_match(strData, '"invid":"S\\u003cb>"', fixed = TRUE)
  expect_false(grepl("</script", strData, fixed = TRUE))
  lData <- rep_DataBlock(html)
  expect_equal(lData$participants$subjid, c("</script><b>x", "P&2"))
  # Script contents are not parsed as HTML; outside them no ID is raw markup.
  # An unescaped </script> would end its block early and leave <b>x behind.
  strOutside <- gsub("<script\\b[^>]*>.*?</script>", "", html, perl = TRUE)
  expect_false(grepl("<b>x", strOutside, fixed = TRUE))
  expect_false(grepl("S<b>", strOutside, fixed = TRUE))
  expect_match(
    gsub("\\s+", " ", html),
    "1 site with participants in more than one country</strong> (S&lt;b&gt;).",
    fixed = TRUE
  )
  for (lPayload in rep_WidgetPayloads(html)) {
    expect_false(grepl("</script", jsonlite::toJSON(lPayload), fixed = TRUE))
  }
})

test_that("a non-default metric Threshold reaches the rate settings and the rule text (#343, #344)", {
  html <- render_rm(dfMetrics = rep_FixtureMetrics(strThreshold = "0.25,0.4"), strFlagRule = "rate")
  lData <- rep_DataBlock(html)
  expect_equal(lData$settings$thresholds$rate, c(0.25, 0.4))
  expect_equal(lData$settings$thresholds$count, c(2, 3))
  expect_match(html, "% of windows that repeat, Amber \u2265 25%, Red \u2265 40%", fixed = TRUE)

  # Under the count rule the metric Threshold still sets the rate settings.
  lData <- rep_DataBlock(render_rm(dfMetrics = rep_FixtureMetrics(strThreshold = "0.25,0.4")))
  expect_equal(lData$settings$thresholds$rate, c(0.25, 0.4))
})
