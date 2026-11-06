test_that("vital rows cover every vital for every participant, flagged rows first (#346)", {
  lClass <- rep_Classify(rep_Fixture(), strFlagRule = "rate")
  df <- rep_VitalRows(lClass)
  # Five participants x (six KRI vitals + height).
  expect_equal(nrow(df), 35)
  expect_equal(df$subjid[1:4], c("A", "B", "D", "D"))
  expect_equal(df$flag[1:4], c("Red", "Red", "Red", "Amber"))
  h <- df[df$subjid == "D" & df$vital == "height", ]
  expect_equal(c(h$metric, h$flag, h$has_repeat), c("", "Red", "Y"))
  expect_true(is.na(df$rate[df$subjid == "E" & df$vital == "weight"]))
  expect_equal(df$rate[df$subjid == "D" & df$vital == "weight"], 0.25)
})

test_that("vital rows count unique values and carry visit details for each value (#346)", {
  df <- rep_VitalRows(rep_Classify(rep_Fixture()))
  d <- df[df$subjid == "D" & df$vital == "weight", ]
  # 90 90 90 91 92 93: 4 unique of 6 values.
  expect_equal(d$n_unique, 4)
  expect_equal(d$measured, 6)
  vVisits <- strsplit(d$visits, "|", fixed = TRUE)[[1]]
  expect_length(vVisits, 6)
  expect_equal(vVisits[1], "#1 \u00b7 V1 \u00b7 2024-01-01")
  expect_equal(vVisits[6], "#6 \u00b7 V6 \u00b7 2024-01-06")
  e <- df[df$subjid == "E" & df$vital == "weight", ]
  expect_equal(c(e$n_unique, e$visits), c("0", ""))
})

test_that("measurements in order and their repeat-window mask match MarkConsecutiveRepeats (#346)", {
  lClass <- rep_Classify(rep_Fixture(), strFlagRule = "rate")
  df <- rep_VitalRows(lClass)
  dfVS <- rep_Fixture()$Mapped_VS
  for (strVital in c("weight", "pulse", "height")) {
    dfMarked <- MarkConsecutiveRepeats(dfVS, strVital)
    for (id in c("A", "B", "D")) {
      d <- dfMarked[dfMarked$subjid == id, ]
      row <- df[df$subjid == id & df$vital == strVital, ]
      strLabel <- paste(id, strVital)
      expect_equal(row$values, paste(d[[strVital]], collapse = " "), label = strLabel)
      expect_equal(row$in_repeat_window, paste(as.integer(d$.rep_in_window), collapse = " "), label = strLabel)
      expect_equal(row$has_repeat, if (any(d$.rep_in_window)) "Y" else "N", label = strLabel)
    }
  }

  # Known answers (see rep_Fixture()).
  mask <- function(id, strVital) df$in_repeat_window[df$subjid == id & df$vital == strVital]
  expect_equal(mask("D", "weight"), "1 1 1 0 0 0")
  expect_equal(mask("A", "weight"), "1 1 1 1")
  expect_equal(mask("B", "pulse"), "1 1 1 0")
  expect_equal(mask("A", "pulse"), "0 0 0")
  expect_equal(df$values[df$subjid == "B" & df$vital == "pulse"], "60 60 60 61")
})

test_that("measurements past V9 follow V9 in the listing (#346)", {
  lClass <- rep_Classify(rep_FixtureLong())
  row <- rep_VitalRows(lClass)
  row <- row[row$subjid == "A" & row$vital == "weight", ]
  expect_equal(row$values, "60 61 62 63 64 65 66 67 80 80 80 90")
  expect_equal(row$in_repeat_window, "0 0 0 0 0 0 0 0 1 1 1 0")
  expect_equal(c(row$Numerator, row$Denominator), c(1, 10))
  expect_equal(
    strsplit(row$visits, "|", fixed = TRUE)[[1]][9:12],
    c("#9 \u00b7 V9 \u00b7 2024-01-09", "#10 \u00b7 V10 \u00b7 2024-01-10", "#11 \u00b7 V11 \u00b7 2024-01-11", "#12 \u00b7 V12 \u00b7 2024-01-12")
  )
  # Visits sorted as text would put V10 to V12 after V1, not V9.
  dfWide <- rep_DataTableWide(lClass)
  expect_equal(dfWide$visit, paste0("V", 1:12))
  expect_equal(dfWide$weight_in_repeat_window, rep(c("N", "Y", "N"), c(8, 3, 1)))
})

test_that("vitals listing is one compact level with flag and rate in one column and CSV only when export is enabled (#346)", {
  skip_if_not_installed("DT")
  lClass <- rep_Classify(rep_Fixture(), strFlagRule = "rate")
  dfRows <- rep_VitalRows(lClass)
  w <- rep_VitalsListing(dfRows, nWindowLength = 3)
  expect_s3_class(w, "datatables")
  expect_equal(w$elementId, "rm-vitals")
  opts <- w$x$options
  expect_equal(opts$dom, "Bfrtip")
  expect_equal(opts$buttons[[1]]$extend, "csv")
  expect_equal(opts$buttons[[1]]$exportOptions$columns, ":visible, .rm-export")
  vNames <- unlist(lapply(opts$columnDefs, `[[`, "name"))
  expect_true(all(c("country", "invid", "subjid", "label", "vital", "has_repeat") %in% vNames))
  # Visible: country, site, participant, vital, measures, flag \u00b7 rate, measurements.
  vHidden <- unlist(lapply(Filter(function(d) isFALSE(d$visible), opts$columnDefs), `[[`, "targets"))
  vShown <- setdiff(seq_along(dfRows) - 1L, vHidden)
  expect_equal(names(dfRows)[vShown + 1L], c("country", "invid", "subjid", "label", "n_unique", "flag", "values"))
  # Metric, measured, N, D, rate and visit details stay in the CSV.
  vExport <- unlist(lapply(Filter(function(d) identical(d$className, "rm-export"), opts$columnDefs), `[[`, "targets"))
  expect_setequal(
    names(dfRows)[vExport + 1L],
    c("metric", "measured", "Numerator", "Denominator", "rate", "in_repeat_window", "visits")
  )
  expect_true("n_unique" %in% vNames)
  expect_match(w$x$container, "Distinct")
  expect_match(w$x$container, "Measurements in order \\(window 3\\)")
  expect_true(isTRUE(opts$deferRender))
  expect_match(w$x$container, "Flag \u00b7 rate")

  wOff <- rep_VitalsListing(dfRows, bExport = FALSE)
  expect_equal(wOff$x$options$dom, "frtip")
  expect_length(wOff$x$options$buttons, 0)
})
