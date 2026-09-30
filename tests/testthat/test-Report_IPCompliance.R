render_ipc <- function(lListings = ipc_Fixture(), ...) {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("DT")
  out <- suppressWarnings(Report_IPCompliance(
    lListings = lListings,
    strOutputDir = tempdir(),
    strOutputFile = paste0(basename(tempfile("ipc")), ".html"),
    ...
  ))
  paste(readLines(out, warn = FALSE), collapse = "\n")
}
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
  html <- render_ipc(dSnapshotDate = ipc_FixtureSnapshotDate)
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

test_that("without discontinuation data the report says so and draws no discontinuation (#320)", {
  html <- render_ipc(
    ipc_Fixture(bPTD = FALSE),
    dSnapshotDate = ipc_FixtureSnapshotDate
  )
  expect_match(
    html,
    "Premature treatment discontinuation data not available",
    fixed = TRUE
  )
  expect_false(grepl("ipc-study-reasons", html, fixed = TRUE))
  data <- jsonlite::fromJSON(sub(
    '.*<script type="application/json" id="ipc-data">(.*?)</script>.*',
    "\\1",
    html
  ))
  expect_false(
    "Premature treatment discontinuation" %in% data$status$study$Status
  )
  expect_null(data$reasons)
})

test_that("a study with no discontinuations yet shows a message, not an empty chart (#320)", {
  f <- ipc_Fixture()
  f$Mapped_SUBJ$drv_treatment_discontinuation_dt <- as.Date(NA)
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
  specs <- bars_specs(render_ipc(dSnapshotDate = ipc_FixtureSnapshotDate))
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
