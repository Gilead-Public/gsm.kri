test_that("long data table has one row per non-missing value, in participant listing order (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_DataTableData(lClass)
  dfVS <- rm_Fixture()$Mapped_VS
  nValues <- sum(!is.na(dfVS$weight)) + sum(!is.na(dfVS$pulse)) + sum(!is.na(dfVS$height))
  expect_equal(nrow(df), nValues)
  expect_equal(
    names(df),
    c("country", "invid", "subjid", "label", "metric", "seq", "visit", "vs_dt", "value", "in_repeat_window", "vital", "has_repeat")
  )
  expect_equal(unique(df$subjid), c("A", "B", "D", "C"))
  d <- df[df$subjid == "D" & df$vital == "weight", ]
  expect_equal(d$seq, 1:6)
  expect_equal(d$value, c("90", "90", "90", "91", "92", "93"))
  expect_equal(d$in_repeat_window, c("Yes", "Yes", "Yes", "No", "No", "No"))
  expect_equal(unique(d$metric), "kri0020a")
  expect_equal(unique(df$metric[df$vital == "height"]), "")
  # has_repeat is participant x vital: every value of a vital with a repeat window.
  expect_true(all(df$has_repeat[df$subjid == "B" & df$vital == "pulse"] == "Y"))
  expect_true(all(df$has_repeat[df$subjid == "B" & df$vital == "weight"] == "N"))
})

test_that("long data table repeat-window values match Mark_ConsecutiveRepeats (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_DataTableData(lClass)
  dfVS <- rm_Fixture()$Mapped_VS
  for (strVital in c("weight", "pulse", "height")) {
    dfMarked <- Mark_ConsecutiveRepeats(dfVS, strVital)
    dfMarked <- dfMarked[order(dfMarked$subjid, dfMarked$seq), ]
    d <- df[df$vital == strVital, ]
    d <- d[order(d$subjid, d$seq), ]
    expect_equal(d$in_repeat_window == "Yes", dfMarked$in_repeat_window, label = strVital)
    expect_equal(as.numeric(d$value), as.numeric(dfMarked[[strVital]]), label = strVital)
  }
})

test_that("wide data table has one row per record, a column per vital and repeat-window flags (#346)", {
  lClass <- rm_Classify(rm_Fixture())
  df <- rm_DataTableWide(lClass)
  dfVS <- rm_Fixture()$Mapped_VS
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

  # Wide red cells equal Long's "In repeat window" values.
  dfLong <- rm_DataTableData(lClass)
  nWide <- sum(unlist(df[grep("_in_repeat_window$", names(df))]) == "Y")
  expect_equal(nWide, sum(dfLong$in_repeat_window == "Yes"))

  lEmpty <- rm_Classify(rm_listings(NULL, rm_Fixture()$Mapped_SUBJ))
  expect_equal(nrow(rm_DataTableWide(lEmpty)), 0)
  expect_equal(nrow(rm_DataTableData(lEmpty)), 0)
})

test_that("performed maps numeric and text codes to Y / N (#346)", {
  expect_equal(rm_Performed(c(1, 0, NA)), c("Y", "N", NA))
  expect_equal(rm_Performed(c("Y", "n", "yes", "No", "U")), c("Y", "N", "Y", "N", "U"))
})

test_that("data table builds Long and Wide tables with CSV only when export is enabled (#346)", {
  skip_if_not_installed("DT")
  lClass <- rm_Classify(rm_Fixture())
  dfLong <- rm_DataTableData(lClass)
  dfWide <- rm_DataTableWide(lClass)
  lDT <- rm_DataTable(dfLong, dfWide, lClass$vitals)
  expect_equal(lDT$long$elementId, "rm-dt-long")
  expect_equal(lDT$wide$elementId, "rm-dt-wide")
  for (w in lDT) {
    opts <- w$x$options
    expect_equal(opts$dom, "Bfrtip")
    expect_equal(opts$pageLength, 25)
    expect_true(opts$deferRender)
    expect_equal(opts$buttons[[1]]$extend, "csv")
  }
  vLongNames <- unlist(lapply(lDT$long$x$options$columnDefs, `[[`, "name"))
  expect_true(all(c("country", "invid", "subjid", "vital", "has_repeat") %in% vLongNames))
  vWideNames <- unlist(lapply(lDT$wide$x$options$columnDefs, `[[`, "name"))
  expect_true(all(c("country", "invid", "subjid", "weight", "pulse", "height", "repeat_vitals") %in% vWideNames))
  # The wide CSV pairs each <vital>_in_repeat_window column with its vital.
  expect_match(as.character(lDT$wide$x$options$buttons[[1]]$exportOptions$columns), '"9":6')

  lOff <- rm_DataTable(dfLong, dfWide, lClass$vitals, bExport = FALSE)
  expect_equal(lOff$long$x$options$dom, "frtip")
  expect_length(lOff$long$x$options$buttons, 0)
  expect_length(lOff$wide$x$options$buttons, 0)
})

test_that("data table headers fit without horizontal scrolling and the CSVs keep every column (#346)", {
  skip_if_not_installed("DT")
  lClass <- rm_Classify(rm_Fixture())
  dfLong <- rm_DataTableData(lClass)
  dfWide <- rm_DataTableWide(lClass)
  lDT <- rm_DataTable(dfLong, dfWide, lClass$vitals)
  defs <- function(w) w$x$options$columnDefs
  hidden <- function(w) {
    unlist(lapply(Filter(function(d) isFALSE(d$visible), defs(w)), `[[`, "targets"))
  }
  idx <- function(df, col) match(col, names(df)) - 1L

  # Wide: abbreviated vital headers with the name and metric on hover.
  strHead <- as.character(lDT$wide$x$container)
  expect_match(strHead, '<th title="Weight (kri0020a)">WT</th>', fixed = TRUE)
  expect_match(strHead, '<th title="Height (no KRI)">Ht</th>', fixed = TRUE)
  # Country moves to a tooltip on the site; Performed greys the row instead.
  expect_true(all(idx(dfWide, c("country", "performed")) %in% hidden(lDT$wide)))
  vRender <- unlist(lapply(defs(lDT$wide), function(d) as.character(d$render)))
  expect_true(any(grepl("title=", vRender, fixed = TRUE)))
  expect_match(as.character(lDT$wide$x$options$createdRow), "rm-np", fixed = TRUE)
  lCSV <- lDT$wide$x$options$buttons[[1]]$exportOptions
  expect_match(as.character(lCSV$columns), sprintf("always = [%d,%d]", idx(dfWide, "country"), idx(dfWide, "performed")), fixed = TRUE)
  expect_match(as.character(lCSV$format$header), '"6":"Weight"', fixed = TRUE)

  # Long: the metric is a KRI badge on the vital and the CSV still has it.
  expect_true(idx(dfLong, "metric") %in% hidden(lDT$long))
  vRender <- unlist(lapply(defs(lDT$long), function(d) as.character(d$render)))
  expect_true(any(grepl("rm-kri", vRender, fixed = TRUE)))
  expect_match(as.character(lDT$long$x$container), ">Repeat<", fixed = TRUE)
  lCSV <- lDT$long$x$options$buttons[[1]]$exportOptions
  expect_true(idx(dfLong, "metric") %in% unlist(lCSV$columns))
  expect_false(any(idx(dfLong, c("vital", "has_repeat")) %in% unlist(lCSV$columns)))
  expect_match(as.character(lCSV$format$header), "In repeat window", fixed = TRUE)
})
