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

test_that("record rows hold every visit with the vitals in a repeat window (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_RecordRows(lClass)
  expect_equal(nrow(df), nrow(rm_Fixture()$Mapped_VS))
  expect_equal(
    names(df),
    c("country", "invid", "subjid", "visit", "vs_dt", "vsperf_std", "weight", "pulse", "height", "repeat_vitals")
  )
  d <- df[df$subjid == "D", ]
  expect_equal(d$repeat_vitals, c("weight height", "weight height", "weight height", "", "", ""))
  b <- df[df$subjid == "B", ]
  expect_equal(b$repeat_vitals, c("pulse", "pulse", "pulse", ""))
  lEmpty <- rm_Classify(rm_listings(NULL, rm_Fixture()$Mapped_SUBJ))
  expect_equal(nrow(rm_RecordRows(lEmpty)), 0)
})

test_that("vitals listing builds both tables with CSV download only when export is enabled (#346)", {
  skip_if_not_installed("DT")
  lClass <- rm_Classify(rm_Fixture())
  lDT <- rm_VitalsListing(rm_VitalRows(lClass), rm_RecordRows(lClass), lClass$vitals)
  expect_equal(lDT$vitals$elementId, "rm-vitals")
  expect_equal(lDT$records$elementId, "rm-records")
  opts <- lDT$vitals$x$options
  expect_equal(opts$dom, "Bfrtip")
  expect_equal(opts$buttons[[1]]$extend, "csv")
  vNames <- unlist(lapply(opts$columnDefs, `[[`, "name"))
  expect_true(all(c("country", "invid", "subjid", "vital", "has_repeat") %in% vNames))
  expect_equal(lDT$records$x$options$buttons[[1]]$extend, "csv")

  lOff <- rm_VitalsListing(rm_VitalRows(lClass), rm_RecordRows(lClass), lClass$vitals, bExport = FALSE)
  expect_equal(lOff$vitals$x$options$dom, "frtip")
  expect_length(lOff$vitals$x$options$buttons, 0)
  expect_length(lOff$records$x$options$buttons, 0)
})
