test_that("report_aegrading module is discoverable and wired to Report_AEGrading", {
  # See test-report_prematuredeath-workflow.R: MakeWorkflowList resolves strPath
  # through base system.file when strPackage is set, which under devtools::test
  # (load_all) points at the source *root* without inst/. Resolve the dir here
  # and pass it as an absolute path with strPackage = NULL.
  dir <- system.file("workflow/4_modules", package = "gsm.kri")
  skip_if(!nzchar(dir), "workflow/4_modules dir not found")

  wf <- workr::MakeWorkflowList(
    strNames = "report_aegrading",
    strPath = dir,
    bExact = TRUE
  )[["report_aegrading"]]

  expect_false(is.null(wf))
  expect_equal(wf$meta$Type, "Report")
  expect_equal(wf$meta$ID, "report_aegrading")
  expect_equal(wf$meta$MetricID, "Analysis_kri0016")
  expect_equal(wf$meta$MinAE, 20)

  step_fns <- vapply(wf$steps, `[[`, character(1), "name")
  expect_true("gsm.kri::Report_AEGrading" %in% step_fns)

  # The report needs both mapped domains it charts from.
  expect_true(all(c("Mapped_AE", "Mapped_SUBJ") %in% names(wf$spec)))
})

test_that("Report_AEGrading validates lListings and nMinAE", {
  expect_error(
    Report_AEGrading(lListings = list(Mapped_AE = data.frame())),
    "Mapped_AE.*Mapped_SUBJ|lListings"
  )

  expect_error(
    Report_AEGrading(
      lListings = list(Mapped_AE = data.frame(), Mapped_SUBJ = data.frame()),
      nMinAE = -1
    ),
    "nMinAE"
  )
})

test_that("AEGrading_SiteDistribution summarizes grades per site", {
  dfAE <- data.frame(
    subjid = c("S1", "S1", "S1", "S2", "S2", "S3"),
    aetoxgr = c(1L, 1L, 3L, 4L, 5L, 2L)
  )
  dfSubj <- data.frame(
    subjid = c("S1", "S2", "S3"),
    invid = c("A", "A", "B")
  )

  out <- AEGrading_SiteDistribution(dfAE, dfSubj, nMinAE = 2)

  # Site B has a single AE, below nMinAE, so only site A survives.
  expect_equal(unique(out$GroupID), "A")
  # All five grades are represented, zero-filled where absent.
  expect_equal(sort(out$Grade), 1:5)
  expect_equal(sum(out$Count), 5)
  expect_equal(out$Proportion[out$Grade == 1], 0.4)
  expect_equal(out$Count[out$Grade == 2], 0)
  # Study proportions are computed before the nMinAE filter, over all 6 events.
  expect_equal(sum(out$StudyProportion), 1)
})

# Fixtures -------------------------------------------------------------------

# Four evaluable sites with deliberately different grade mixes, plus one site
# below nMinAE. A over-grades (mostly Grade 3+), B under-grades (mostly Grade
# 1), C and D sit near the study mix.
aegrading_listings <- function() {
  vGrades <- list(
    A = c(rep(1, 2), rep(2, 3), rep(3, 10), rep(4, 6), rep(5, 3)),
    B = c(rep(1, 20), rep(2, 3), rep(3, 1)),
    C = c(rep(1, 10), rep(2, 6), rep(3, 4), rep(4, 2)),
    D = c(rep(1, 9), rep(2, 7), rep(3, 3), rep(4, 1), rep(5, 1)),
    E = c(1, 2, 3)
  )
  dfAE <- do.call(rbind, lapply(names(vGrades), function(site) {
    data.frame(
      subjid = paste0(site, "-", seq_along(vGrades[[site]]) %% 3),
      aetoxgr = as.integer(vGrades[[site]])
    )
  }))
  dfSubj <- data.frame(subjid = unique(dfAE$subjid))
  dfSubj$invid <- sub("-.*", "", dfSubj$subjid)
  list(Mapped_AE = dfAE, Mapped_SUBJ = dfSubj)
}

aegrading_results <- function() {
  df <- data.frame(
    MetricID = rep(c("Analysis_kri0016", "Analysis_kri0017"), each = 4),
    GroupLevel = "Site",
    GroupID = rep(c("A", "B", "C", "D"), 2),
    Numerator = c(19, 1, 6, 5, 2, 20, 10, 9),
    Denominator = rep(c(24, 24, 22, 21), 2),
    Score = c(3.4, -2.3, 0.2, NA, -2.5, 3.1, 0.4, NA),
    Flag = c(2, -1, 0, NA, -1, 2, 0, NA),
    StudyID = "STUDY-1",
    SnapshotDate = as.Date("2026-01-31")
  )
  df$Metric <- df$Numerator / df$Denominator
  # A country-level row must never leak into the site-level flagged table.
  rbind(
    df,
    transform(df[1, ], GroupLevel = "Country", GroupID = "US", Flag = 2)
  )
}

bars_spec <- function(widget) {
  jsonlite::fromJSON(widget$x$spec, simplifyVector = FALSE)
}

bars_data <- function(widget) {
  jsonlite::fromJSON(widget$x$data)
}

# Rows of the "Flagged sites" gt table as a Site -> Direction named vector.
flagged_directions <- function(strHtml) {
  doc <- xml2::read_html(strHtml)
  tables <- xml2::xml_find_all(doc, "//table")
  headers <- lapply(tables, function(t) {
    xml2::xml_text(xml2::xml_find_all(t, ".//thead//th"), trim = TRUE)
  })
  idx <- which(vapply(headers, function(h) "Direction" %in% h, logical(1)))
  if (length(idx) == 0) {
    return(character(0))
  }
  tbl <- tables[[idx[1]]]
  hdr <- headers[[idx[1]]]
  rows <- xml2::xml_find_all(tbl, ".//tbody/tr")
  cells <- lapply(rows, function(r) {
    xml2::xml_text(xml2::xml_find_all(r, "./td"), trim = TRUE)
  })
  stats::setNames(
    vapply(cells, `[`, character(1), match("Direction", hdr)),
    vapply(cells, `[`, character(1), match("Site", hdr))
  )
}

render_aegrading <- function(...) {
  strDir <- withr::local_tempdir(.local_envir = parent.frame())
  strPath <- suppressWarnings(Report_AEGrading(
    lListings = aegrading_listings(),
    strOutputDir = strDir,
    ...
  ))
  paste(readLines(strPath, warn = FALSE), collapse = "\n")
}

# Visualize_GradeBySite --------------------------------------------------------

test_that("Visualize_GradeBySite returns a percent-stacked gsm.vizr bars widget (#317)", {
  lListings <- aegrading_listings()
  dfDist <- AEGrading_SiteDistribution(
    lListings$Mapped_AE,
    lListings$Mapped_SUBJ
  )

  widget <- Visualize_GradeBySite(dfDist)
  spec <- bars_spec(widget)

  expect_s3_class(widget, "bars")
  expect_s3_class(widget, "htmlwidget")
  expect_equal(spec$orientation, "horizontal")
  expect_equal(spec$position, "stack")
  expect_equal(spec$stat, "percent")
  expect_setequal(
    unique(bars_data(widget)$Grade),
    paste("Grade", 1:5)
  )
})

test_that("Visualize_GradeBySite orders sites by Grade 3+ share and draws the study reference line (#317)", {
  lListings <- aegrading_listings()
  dfDist <- AEGrading_SiteDistribution(
    lListings$Mapped_AE,
    lListings$Mapped_SUBJ
  )

  spec <- bars_spec(Visualize_GradeBySite(dfDist))

  # Ascending Grade 3+ share: B (1/24) < D (5/21) < C (6/22) < A (19/24).
  expect_equal(unlist(spec$scales$x$order), c("B", "D", "C", "A"))

  # The reference line sits where the Grade 3+ segment begins on a 0-100
  # stacked axis. Study-wide share includes site E, which nMinAE excluded.
  nStudyHigh <- sum(lListings$Mapped_AE$aetoxgr >= 3) /
    nrow(lListings$Mapped_AE)
  refLine <- spec$annotations$referenceLines[[1]]
  # JSON serialization keeps ~6 significant digits.
  expect_equal(refLine$value, (1 - nStudyHigh) * 100, tolerance = 1e-5)
  expect_match(
    spec$labels$captions,
    paste0("(", round(nStudyHigh * 100, 1), "%)"),
    fixed = TRUE
  )
})

test_that("Visualize_GradeBySite marks flagged sites in both directions only (#317)", {
  lListings <- aegrading_listings()
  dfDist <- AEGrading_SiteDistribution(
    lListings$Mapped_AE,
    lListings$Mapped_SUBJ
  )
  dfFlagged <- data.frame(
    GroupID = c("A", "B", "C", "D"),
    Flag = c(2, -1, 0, NA)
  )

  widget <- Visualize_GradeBySite(dfDist, dfFlagged = dfFlagged)
  spec <- bars_spec(widget)
  vLabels <- unique(bars_data(widget)$GroupLabel)

  # Over- (A, +2) and under-graders (B, -1) are both marked; a zero flag (C)
  # and an accrual-suppressed NA flag (D) are not.
  expect_setequal(vLabels, c("▶ A", "▶ B", "C", "D"))
  # The axis order must use the same labels as the data, or bars go missing.
  expect_setequal(unlist(spec$scales$x$order), vLabels)
  expect_match(spec$labels$captions, "flagged by the grading KRI", fixed = TRUE)
})

test_that("Visualize_GradeBySite marks nothing when no sites are flagged (#317)", {
  lListings <- aegrading_listings()
  dfDist <- AEGrading_SiteDistribution(
    lListings$Mapped_AE,
    lListings$Mapped_SUBJ
  )

  for (dfFlagged in list(
    NULL,
    data.frame(GroupID = character(0), Flag = numeric(0)),
    data.frame(GroupID = c("A", "B"), Flag = c(0, NA))
  )) {
    widget <- Visualize_GradeBySite(dfDist, dfFlagged = dfFlagged)
    expect_false(any(grepl("▶", bars_data(widget)$GroupLabel)))
    expect_no_match(
      bars_spec(widget)$labels$captions,
      "flagged by the grading KRI",
      fixed = TRUE
    )
  }
})

# AEGrading_Direction ------------------------------------------------------------

test_that("AEGrading_Direction reads a high-grade flag as the grading direction (#317)", {
  expect_equal(
    AEGrading_Direction(c(2, 1, -1, -2), "Analysis_kri0016"),
    c("Over-grading", "Over-grading", "Under-grading", "Under-grading")
  )
})

test_that("AEGrading_Direction inverts a low-grade flag: excess Grade 1 is under-grading (#317)", {
  expect_equal(
    AEGrading_Direction(c(2, 1, -1, -2), "Analysis_kri0017"),
    c("Under-grading", "Under-grading", "Over-grading", "Over-grading")
  )
})

# Report_AEGrading rendering -------------------------------------------------

test_that("Report_AEGrading renders the chart and flagged-site directions for kri0016 (#317)", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("withr")

  strHtml <- render_aegrading(dfResults = aegrading_results())

  expect_match(strHtml, "AE Grading Overview", fixed = TRUE)
  expect_match(strHtml, "Study: STUDY-1", fixed = TRUE)
  expect_match(strHtml, "Snapshot Date: 2026-01-31", fixed = TRUE)
  expect_match(strHtml, "EXPERIMENTAL", fixed = TRUE)
  expect_match(strHtml, "class=\"bars html-widget", fixed = TRUE)

  # Sorted by |Score|: A (+3.4) then B (-2.3). C (Flag 0), D (NA flag) and the
  # country-level row are excluded.
  expect_equal(
    flagged_directions(strHtml),
    c(A = "Over-grading", B = "Under-grading")
  )
})

test_that("Report_AEGrading reverses the direction label for the low-grade metric kri0017 (#317)", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("withr")

  strHtml <- render_aegrading(
    dfResults = aegrading_results(),
    strMetricID = "Analysis_kri0017"
  )

  # B has an excess of Grade 1 events (Flag +2), which is under-grading; A has
  # too few (Flag -1), which is over-grading.
  expect_equal(
    flagged_directions(strHtml),
    c(B = "Under-grading", A = "Over-grading")
  )
})

test_that("Report_AEGrading renders without results or flags (#317)", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("withr")

  strHtml <- render_aegrading(dfResults = NULL)
  expect_match(strHtml, "No metric results were supplied", fixed = TRUE)
  expect_length(flagged_directions(strHtml), 0)

  dfNoFlags <- aegrading_results()
  dfNoFlags$Flag <- 0
  strHtml <- render_aegrading(dfResults = dfNoFlags)
  expect_match(strHtml, "No sites were flagged", fixed = TRUE)
  expect_length(flagged_directions(strHtml), 0)
})
