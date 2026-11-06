# Expands Wide as rmFilters.js longRows() does: one row per participant,
# measure and non-missing value, # counting values in Wide row order.
rep_WideToLong <- function(dfWide, vVitals) {
  vVitals <- intersect(vVitals, names(dfWide))
  df <- dplyr::bind_rows(lapply(seq_along(vVitals), function(j) {
    v <- vVitals[[j]]
    x <- dfWide[[v]]
    keep <- !is.na(x) & as.character(x) != ""
    tibble::tibble(
      p = match(dfWide$subjid, unique(dfWide$subjid))[keep],
      j = j,
      subjid = dfWide$subjid[keep],
      vital = v,
      value = as.character(x[keep]),
      in_repeat_window = dfWide[[paste0(v, "_in_repeat_window")]][keep] == "Y"
    )
  }))
  df <- dplyr::mutate(dplyr::group_by(df, .data$subjid, .data$vital), seq = dplyr::row_number())
  dplyr::ungroup(df[order(df$p, df$j, df$seq), ])
}

test_that("Long rows built from Wide reproduce rep_Classify() measurements (#346)", {
  fBP <- rep_Fixture()
  fBP$Mapped_VS$sysbp <- ifelse(fBP$Mapped_VS$subjid == "A", 120, NA)
  fBP$Mapped_VS$diabp <- ifelse(fBP$Mapped_VS$subjid == "A", c(80, 80, 80, 81), NA)
  # Reversed input with a tied date, a missing date and decimals: Wide must
  # still follow measurement order.
  fMessy <- rep_Fixture()
  dfVS <- fMessy$Mapped_VS[rev(seq_len(nrow(fMessy$Mapped_VS))), ]
  dfVS$vs_dt[2] <- dfVS$vs_dt[1]
  dfVS$vs_dt[3] <- NA
  dfVS$weight <- dfVS$weight + 0.25
  fMessy$Mapped_VS <- dfVS
  for (lListings in list(rep_Fixture(), rep_FixtureEdge(), rep_FixtureSplit(), fBP, fMessy)) {
    # rep_FixtureSplit() warns about its split site.
    lClass <- suppressWarnings(rep_Classify(lListings))
    dfLong <- rep_WideToLong(rep_DataTableWide(lClass), lClass$vitals$vital)
    dfM <- lClass$measurements
    dfM <- dfM[order(dfM$subjid, dfM$vital, dfM$seq), ]
    dfLong <- dfLong[order(dfLong$subjid, dfLong$vital, dfLong$seq), ]
    expect_equal(nrow(dfLong), nrow(dfM))
    expect_equal(dfLong$seq, dfM$seq)
    expect_equal(dfLong$in_repeat_window, dfM$in_repeat_window)
    expect_equal(dfLong$value, dfM$value_text)
  }
  d <- rep_WideToLong(rep_DataTableWide(rep_Classify(rep_Fixture())), c("weight", "pulse", "height"))
  expect_equal(unique(d$subjid), c("A", "B", "D", "C"))
  expect_equal(d$value[d$subjid == "D" & d$vital == "weight"], c("90", "90", "90", "91", "92", "93"))
})

test_that("wide data table has one row per record, a column per vital and repeat-window flags (#346)", {
  lClass <- rep_Classify(rep_Fixture())
  df <- rep_DataTableWide(lClass)
  dfVS <- rep_Fixture()$Mapped_VS
  expect_equal(nrow(df), nrow(dfVS))
  expect_equal(
    names(df),
    c(
      "country", "invid", "subjid", "visit", "vs_dt", "performed", "weight", "pulse", "height",
      "weight_in_repeat_window", "pulse_in_repeat_window", "height_in_repeat_window", "repeat_vitals"
    )
  )
  expect_equal(unique(df$subjid), c("A", "B", "D", "C"))
  expect_true(all(df$performed == "Y"))
  d <- df[df$subjid == "D", ]
  expect_equal(d$visit, paste0("V", 1:6))
  expect_equal(d$weight_in_repeat_window, c("Y", "Y", "Y", "N", "N", "N"))
  expect_equal(d$height_in_repeat_window, c("Y", "Y", "Y", "", "", ""))
  expect_equal(d$pulse_in_repeat_window, rep("", 6))
  expect_true(all(d$repeat_vitals == "weight height"))
  expect_true(all(df$repeat_vitals[df$subjid == "C"] == ""))

  # Wide red cells equal the measurements in a repeating window.
  nWide <- sum(unlist(df[grep("_in_repeat_window$", names(df))]) == "Y")
  expect_equal(nWide, sum(lClass$measurements$in_repeat_window))

  lEmpty <- rep_Classify(rep_listings(NULL, rep_Fixture()$Mapped_SUBJ))
  expect_equal(nrow(rep_DataTableWide(lEmpty)), 0)
})

test_that("performed maps numeric and text codes to Y / N (#346)", {
  expect_equal(rep_Performed(c(1, 0, NA)), c("Y", "N", NA))
  expect_equal(rep_Performed(c("Y", "n", "yes", "No", "U")), c("Y", "N", "Y", "N", "U"))
})

test_that("data table builds the Wide table with a CSV only when export is enabled (#346)", {
  skip_if_not_installed("DT")
  lClass <- rep_Classify(rep_Fixture())
  dfWide <- rep_DataTableWide(lClass)
  w <- rep_DataTable(dfWide, lClass$vitals)
  expect_equal(w$elementId, "rm-dt-wide")
  opts <- w$x$options
  expect_equal(opts$dom, "Bfrtip")
  expect_equal(opts$pageLength, 25)
  expect_true(opts$deferRender)
  expect_equal(opts$buttons[[1]]$extend, "csv")
  # rmFilters.js finds every column by name, including those it reads to build Long.
  vNames <- unlist(lapply(opts$columnDefs, `[[`, "name"))
  expect_setequal(vNames, names(dfWide))
  # The wide CSV pairs each <vital>_in_repeat_window column with its measure.
  expect_match(as.character(opts$buttons[[1]]$exportOptions$columns), '"9":6')

  wOff <- rep_DataTable(dfWide, lClass$vitals, bExport = FALSE)
  expect_equal(wOff$x$options$dom, "frtip")
  expect_length(wOff$x$options$buttons, 0)
})

test_that("data table headers fit without horizontal scrolling and the CSV keeps every column (#346)", {
  skip_if_not_installed("DT")
  lClass <- rep_Classify(rep_Fixture())
  dfWide <- rep_DataTableWide(lClass)
  w <- rep_DataTable(dfWide, lClass$vitals)
  defs <- w$x$options$columnDefs
  hidden <- unlist(lapply(Filter(function(d) isFALSE(d$visible), defs), `[[`, "targets"))
  idx <- function(df, col) match(col, names(df)) - 1L

  # Abbreviated measure headers with the name and metric on hover.
  strHead <- as.character(w$x$container)
  expect_match(strHead, '<th title="Weight (kri0020a)">WT</th>', fixed = TRUE)
  expect_match(strHead, '<th title="Height (no KRI)">Ht</th>', fixed = TRUE)
  # Country moves to a tooltip on the site; Performed greys the row instead.
  expect_true(all(idx(dfWide, c("country", "performed")) %in% hidden))
  vRender <- unlist(lapply(defs, function(d) as.character(d$render)))
  expect_true(any(grepl("title=", vRender, fixed = TRUE)))
  expect_match(as.character(w$x$options$createdRow), "rm-np", fixed = TRUE)
  lCSV <- w$x$options$buttons[[1]]$exportOptions
  expect_match(as.character(lCSV$columns), sprintf("always = [%d,%d]", idx(dfWide, "country"), idx(dfWide, "performed")), fixed = TRUE)
  expect_match(as.character(lCSV$format$header), '"6":"Weight"', fixed = TRUE)
})

test_that("Wide rows without vsperf_std leave performed missing, without a warning (#346)", {
  lClass <- rep_Classify(rep_listings(rep_vs(list(A = c(1, 1, 1), B = c(2, 3, 4)))))
  expect_false("vsperf_std" %in% names(lClass$records))
  expect_no_warning(dfWide <- rep_DataTableWide(lClass))
  expect_equal(nrow(dfWide), 6)
  expect_true(all(is.na(dfWide$performed)))
})
