test_that("rep_Seg keeps the attribute order rmFilters.js and the report tests rely on", {
  # Without a group the data attribute holds the value.
  html <- as.character(rep_Seg("Table shape", c(wide = "Wide", long = "Long"), "wide", "data-rm-shape", strIdPrefix = "rm-shape-"))
  expect_match(html, '<span class="rm-seg" role="group" aria-label="Table shape">', fixed = TRUE)
  expect_match(html, '<button id="rm-shape-wide" type="button" data-rm-shape="wide" aria-pressed="true">Wide</button>', fixed = TRUE)
  expect_match(html, '<button id="rm-shape-long" type="button" data-rm-shape="long" aria-pressed="false">Long</button>', fixed = TRUE)

  # With a group the data attribute names the group and value holds the value.
  html <- as.character(rep_Seg("Flag rule", c(count = "# repeating", rate = "% repeating"), "rate", "data-rm-set", strGroup = "rule"))
  expect_match(html, '<button type="button" data-rm-set="rule" value="count" aria-pressed="false"># repeating</button>', fixed = TRUE)
  expect_match(html, '<button type="button" data-rm-set="rule" value="rate" aria-pressed="true">% repeating</button>', fixed = TRUE)
  expect_no_match(html, "id=", fixed = TRUE)
})

test_that("rep_Header shows the context line and snapshot only when given", {
  lClass <- rep_Quietly(rep_Classify(rep_Fixture()))
  html <- gsub("\\s+", " ", as.character(rep_Header(lClass, "STUDY1")))
  expect_no_match(html, "rm-ctx", fixed = TRUE)
  expect_no_match(html, "Snapshot", fixed = TRUE)
  expect_match(html, "<b>Study</b> STUDY1", fixed = TRUE)
  expect_match(html, "<b>Window</b> 3 measurements", fixed = TRUE)
  expect_match(html, "repeating windows, Amber \u2265 2, Red \u2265 3; participants need 1 window for a flag", fixed = TRUE)

  html <- gsub("\\s+", " ", as.character(rep_Header(lClass, "STUDY1", as.Date("2025-01-31"), '<a href="study.html">Back</a>')))
  expect_match(html, '<div class="rm-ctx"><a href="study.html">Back</a></div>', fixed = TRUE)
  expect_match(html, "<b>Snapshot</b> 2025-01-31", fixed = TRUE)
})

test_that("rep_Toolbar lists every measure and starts the settings from lSettings", {
  lClass <- rep_Quietly(rep_Classify(rep_Fixture()))
  lSettings <- list(rule = "rate", bp = "both")
  html <- as.character(rep_Toolbar(lClass$vitals, lSettings))
  for (v in lClass$vitals$vital) {
    expect_match(html, sprintf('data-rm-vital-opt="%s"', v), fixed = TRUE)
  }
  expect_match(html, 'data-rm-set="rule" value="rate" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'data-rm-set="bp" value="both" aria-pressed="true"', fixed = TRUE)
  expect_match(html, 'id="rm-settings"', fixed = TRUE)
})
