test_that("vital rows cover every vital for every participant, flagged rows first (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_VitalRows(lClass)
  # Five participants x (six KRI vitals + height).
  expect_equal(nrow(df), 35)
  expect_equal(df$subjid[1:3], c("A", "B", "D"))
  expect_equal(df$flag[1:3], c("Red", "Red", "Amber"))
  h <- df[df$subjid == "D" & df$vital == "height", ]
  expect_equal(c(h$metric, h$flag, h$has_repeat), c("", "No KRI", "Y"))
  expect_true(is.na(df$rate[df$subjid == "E" & df$vital == "weight"]))
  expect_equal(df$rate[df$subjid == "D" & df$vital == "weight"], 0.25)
})

test_that("measurements in order and their repeat-window mask match Mark_ConsecutiveRepeats (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_VitalRows(lClass)
  dfVS <- rm_Fixture()$Mapped_VS
  for (strVital in c("weight", "pulse", "height")) {
    dfMarked <- Mark_ConsecutiveRepeats(dfVS, strVital)
    for (id in c("A", "B", "D")) {
      d <- dfMarked[dfMarked$subjid == id, ]
      row <- df[df$subjid == id & df$vital == strVital, ]
      strLabel <- paste(id, strVital)
      expect_equal(row$values, paste(d[[strVital]], collapse = " "), label = strLabel)
      expect_equal(row$in_repeat_window, paste(as.integer(d$in_repeat_window), collapse = " "), label = strLabel)
      expect_equal(row$has_repeat, if (any(d$in_repeat_window)) "Y" else "N", label = strLabel)
    }
  }
})

test_that("vitals listing is one compact level with flag and rate in one column and CSV only when export is enabled (#346)", {
  skip_if_not_installed("DT")
  lClass <- rm_Classify(rm_Fixture())
  dfRows <- rm_VitalRows(lClass)
  w <- rm_VitalsListing(dfRows, nWindowLength = 3)
  expect_s3_class(w, "datatables")
  expect_equal(w$elementId, "rm-vitals")
  opts <- w$x$options
  expect_equal(opts$dom, "Bfrtip")
  expect_equal(opts$buttons[[1]]$extend, "csv")
  expect_equal(opts$buttons[[1]]$exportOptions$columns, ":visible, .rm-export")
  vNames <- unlist(lapply(opts$columnDefs, `[[`, "name"))
  expect_true(all(c("country", "invid", "subjid", "label", "vital", "has_repeat") %in% vNames))
  # Visible: country, site, participant, vital, flag \u00b7 rate, measurements.
  vHidden <- unlist(lapply(Filter(function(d) isFALSE(d$visible), opts$columnDefs), `[[`, "targets"))
  vShown <- setdiff(seq_along(dfRows) - 1L, vHidden)
  expect_equal(names(dfRows)[vShown + 1L], c("country", "invid", "subjid", "label", "flag", "values"))
  # Metric, measured, N, D and rate stay in the CSV.
  vExport <- unlist(lapply(Filter(function(d) identical(d$className, "rm-export"), opts$columnDefs), `[[`, "targets"))
  expect_setequal(
    names(dfRows)[vExport + 1L],
    c("metric", "measured", "Numerator", "Denominator", "rate", "in_repeat_window")
  )
  expect_match(w$x$container, "Measurements in order \\(W = 3\\)")
  expect_match(w$x$container, "Flag \u00b7 rate")

  wOff <- rm_VitalsListing(dfRows, bExport = FALSE)
  expect_equal(wOff$x$options$dom, "frtip")
  expect_length(wOff$x$options$buttons, 0)
})
