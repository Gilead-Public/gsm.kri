render_eligibility <- function(lListings, dfResults = elig_FixtureResults(), dfGroups = elig_FixtureGroups(), strMode = "basic") {
  dir <- withr::local_tempdir()
  out <- quiet_render(Report_Eligibility(
    dfResults = dfResults,
    dfMetrics = elig_FixtureMetrics(),
    dfGroups = dfGroups,
    lListings = lListings,
    strOutputDir = dir,
    strMode = strMode
  ))
  expect_true(file.exists(out))
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

elig_listings <- function(df, ...) list(IE_num = df[df$Source != "Neither", ], IE_denom = df, ...)

test_that("the report no longer depends on gsm.qtl (#371)", {
  rmd <- paste(readLines(system.file("report", "Report_Eligibility.Rmd", package = "gsm.kri"), warn = FALSE), collapse = "\n")
  expect_false(grepl("gsm.qtl", rmd, fixed = TRUE))
  expect_false(grepl("gsm.qtl", paste(deparse(body(Report_Eligibility)), collapse = "\n"), fixed = TRUE))
})

test_that("basic mode renders with two statuses and no pilot sections (#371, #160)", {
  html <- render_eligibility(elig_listings(elig_Fixture()))
  expect_false(grepl("plotly", html, ignore.case = TRUE))
  expect_false(grepl("Potentially Ineligible", html, fixed = TRUE))
  expect_false(grepl("Deep Dive Listing", html, fixed = TRUE))
  expect_false(grepl("Status over Time", html, fixed = TRUE))
  expect_true(grepl("Ineligibility Listing", html, fixed = TRUE))
  expect_false(grepl("Inclusion/Exclusion Listing", html, fixed = TRUE))
})

test_that("pilot mode renders the third status, the listing's records and status over time (#371, #160)", {
  html <- render_eligibility(
    elig_listings(elig_Fixture(bPilot = TRUE), IE_records = elig_FixtureRecords()),
    dfResults = elig_FixtureResults(bRisk = TRUE),
    strMode = "pilot"
  )
  expect_false(grepl("plotly", html, ignore.case = TRUE))
  expect_true(grepl("Potentially Ineligible", html, fixed = TRUE))
  expect_false(grepl("Deep Dive Listing", html, fixed = TRUE))
  expect_true(grepl("Status over Time", html, fixed = TRUE))
  expect_true(grepl("Please check I/E", html, fixed = TRUE))
  expect_true(grepl("EDC Query details", html, fixed = TRUE))
})

test_that("pilot mode degrades without site groups, history metric, records or EDC PD (#371)", {
  html <- render_eligibility(
    elig_listings(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE)),
    dfGroups = elig_FixtureGroups(bSites = FALSE),
    strMode = "pilot"
  )
  expect_true(grepl("Potentially Ineligible", html, fixed = TRUE))
  expect_false(grepl("Status over Time", html, fixed = TRUE))
  expect_false(grepl("Deep Dive Listing", html, fixed = TRUE))
  expect_true(grepl("EDC PD is N/A", html, fixed = TRUE))
})

test_that("pilot mode shows EDC Query as N/A when the source is not delivered (#371)", {
  df <- elig_Fixture(bPilot = TRUE)
  df$edc_query <- NA_character_
  html <- render_eligibility(elig_listings(df), strMode = "pilot")
  expect_true(grepl("Potentially Ineligible", html, fixed = TRUE))
  expect_true(grepl("EDC Query is N/A", html, fixed = TRUE))
  expect_false(grepl("EDC PD is N/A", html, fixed = TRUE))
})

test_that("pilot mode without EDC source data warns the caller and renders the basic report (#371)", {
  df <- elig_Fixture(bPilot = TRUE)
  df$edc_query <- NA_character_
  df$edc_pd <- NA_character_
  expect_warning(html <- render_eligibility(elig_listings(df), strMode = "pilot"), "basic")
  expect_false(grepl("Potentially Ineligible", html, fixed = TRUE))
})

test_that("the edc_query column alone does not switch on pilot mode (#371)", {
  html <- render_eligibility(elig_listings(elig_Fixture(bPilot = TRUE)))
  expect_false(grepl("Potentially Ineligible", html, fixed = TRUE))
})

test_that("the older RenderRmd call style still renders the report (#371)", {
  out <- quiet_render(RenderRmd(
    lParams = list(
      dfResults = elig_FixtureResults(),
      dfMetrics = elig_FixtureMetrics(),
      dfGroups = elig_FixtureGroups(),
      lListings = elig_listings(elig_Fixture())
    ),
    strOutputDir = withr::local_tempdir(),
    strOutputFile = "Report_Eligibility.html",
    strInputPath = system.file("report", "Report_Eligibility.Rmd", package = "gsm.kri")
  ))
  expect_true(file.exists(out))
})
