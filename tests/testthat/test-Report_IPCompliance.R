render_ipc <- function(lListings = ipc_Fixture(), ...) {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- quiet_render(suppressWarnings(Report_IPCompliance(
    lListings = lListings,
    strOutputDir = tempdir(),
    strOutputFile = paste0(basename(tempfile("ipc")), ".html"),
    ...
  )))
  paste(readLines(out, warn = FALSE), collapse = "\n")
}
# Each render takes several seconds, so share the default render across tests.
ipc_default_html <- local({
  html <- NULL
  function() {
    if (is.null(html)) {
      html <<- render_ipc(dSnapshotDate = ipc_FixtureSnapshotDate)
    }
    html
  }
})
# gsm.vizr serializes each widget's spec into a JSON <script data-for=...> block.
bars_specs <- function(html) {
  payloads <- stringr::str_match_all(
    html,
    '<script type="application/json" data-for="htmlwidget-[^"]*">(.*?)</script>'
  )[[1]][, 2]
  specs <- lapply(payloads, function(p) {
    jsonlite::fromJSON(p, simplifyVector = FALSE)$x
  })
  Filter(function(x) !is.null(x$spec) && !is.null(x$metadata), specs)
}

test_that("Report_IPCompliance renders to a file (#320)", {
  html <- ipc_default_html()
  expect_match(
    html,
    "IP monitoring: IP Non-Starter &amp; Premature Treatment",
    fixed = TRUE
  )
  expect_match(html, "Snapshot date: 2026-06-30", fixed = TRUE)
  for (id in c("ipc-study-status", "ipc-country-reasons", "ipc-site-status")) {
    expect_match(html, paste0('"chartId":"', id, '"'), fixed = TRUE)
  }
  for (id in c(
    "ipc-study-tte",
    "ipc-country-tte",
    "ipc-site-tte",
    "ipc-filter-strip",
    "ipc-dosed-Y",
    "ipc-chip-site"
  )) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  expect_match(html, 'id="ipc-data"', fixed = TRUE)
})

test_that("the snapshot date defaults to the latest reporting snapshot (#320)", {
  dfResults <- data.frame(SnapshotDate = as.Date(c("2026-05-01", "2026-07-01")))
  expect_match(
    render_ipc(dfResults = dfResults),
    "Snapshot date: 2026-07-01",
    fixed = TRUE
  )
  expect_error(Report_IPCompliance(lListings = ipc_Fixture()), "dSnapshotDate")
})

test_that("without drv_drg_completion the report says so and shows dosed participants as Unrecognized (#320, #332)", {
  html <- render_ipc(
    ipc_Fixture(bPTD = FALSE),
    dSnapshotDate = ipc_FixtureSnapshotDate
  )
  expect_match(html, "Treatment completion data not available", fixed = TRUE)
  expect_false(grepl("ipc-study-reasons", html, fixed = TRUE))
  data <- jsonlite::fromJSON(sub(
    '.*<script type="application/json" id="ipc-data">(.*?)</script>.*',
    "\\1",
    html
  ))
  study <- data$status$study
  expect_false(
    any(c("Premature treatment discontinuation", "Treatment ongoing") %in%
      study$Status)
  )
  expect_true(
    "Unrecognized status" %in% study$Status[study$Dosed == "Y"]
  )
  expect_true("Confirmed IP non-starter" %in% study$Status)
  expect_null(data$reasons)
})

test_that("a study with no discontinuations yet shows a message, not an empty chart (#320, #332)", {
  f <- ipc_Fixture()
  f$Mapped_SUBJ$drv_drg_completion[f$Mapped_SUBJ$drv_drg_completion %in% "N"] <- "Y"
  html <- render_ipc(f, dSnapshotDate = ipc_FixtureSnapshotDate)
  expect_match(
    html,
    "No premature treatment discontinuations recorded.",
    fixed = TRUE
  )
  expect_false(grepl("ipc-study-reasons", html, fixed = TRUE))
})

test_that("no enrolled participants renders the empty state (#320)", {
  f <- lapply(ipc_Fixture(), function(df) df[0, ])
  html <- render_ipc(f, dSnapshotDate = ipc_FixtureSnapshotDate)
  expect_match(html, "No enrolled participants.", fixed = TRUE)
  expect_false(grepl('id="ipc-data"', html, fixed = TRUE))
})

test_that("inlined data cannot close its script block (#320)", {
  f <- ipc_Fixture()
  f$Mapped_IPNS$invid[1] <- "JP01</script><script>alert(1)"
  html <- render_ipc(f, dSnapshotDate = ipc_FixtureSnapshotDate)
  data <- sub(
    '.*<script type="application/json" id="ipc-data">(.*?)</script>.*',
    "\\1",
    html
  )
  expect_false(grepl("<", data, fixed = TRUE))
  expect_match(data, "\\u003c\\/script", fixed = TRUE)
})

test_that("bar charts render through gsm.vizr::bars with the status stack (#320)", {
  specs <- bars_specs(ipc_default_html())
  ids <- vapply(specs, function(x) x$metadata$chartId, "")
  expect_setequal(
    ids,
    paste0(
      "ipc-",
      rep(c("study", "country", "site"), each = 2),
      c("-status", "-reasons")
    )
  )
})

test_that("the filter script is inlined once (#320)", {
  html <- ipc_default_html()
  # gregexpr() returns -1 for no match, so count positive positions.
  hits <- gregexpr("window.ipcRegisterScatter = function", html, fixed = TRUE)[[1]]
  expect_equal(sum(hits > 0), 1L)
  expect_match(html, "gsm-viz-select", fixed = TRUE)
})

test_that("the scatter note places events above the diagonal (#320)", {
  html <- ipc_default_html()
  # Pandoc may wrap the sentence across lines.
  expect_match(html, "Points above it\\s+had their event")
  expect_false(grepl("Points below it", html, fixed = TRUE))
})

test_that("the report shows the treatment completion statuses, not Study complete or Ongoing (#332)", {
  html <- ipc_default_html()
  # Pandoc may wrap a definition across lines.
  for (status in c(
    "Potential premature treatment discontinuation",
    "Treatment complete per protocol",
    "Treatment ongoing"
  )) {
    expect_match(html, gsub(" ", "\\\\s+", status), label = status)
  }
  expect_match(html, "did\\s+not\\s+complete\\s+study\\s+drug\\s+per\\s+protocol")
  expect_false(grepl("Study complete", html, fixed = TRUE))
  expect_false(grepl("\\bOngoing\\b", html))
})
