test_that("tiles widget is an in-repo htmlwidget with no gsm.viz bundle (#347)", {
  dfTiles <- rm_ParticipantTiles(rm_Classify(rm_Fixture()))
  w <- Widget_RepeatMeasurementsTiles(dfTiles)
  expect_s3_class(w, "Widget_RepeatMeasurementsTiles")
  expect_s3_class(w, "htmlwidget")
  expect_equal(w$elementId, "rm-tiles")
  deps <- htmlwidgets::getDependency("Widget_RepeatMeasurementsTiles", "gsm.kri")
  vNames <- vapply(deps, `[[`, character(1), "name")
  expect_false("gsmViz" %in% vNames)
  expect_true("renderRepeatMeasurementsTiles.js" %in% unlist(lapply(deps, `[[`, "script")))
  expect_true("renderRepeatMeasurementsTiles.css" %in% unlist(lapply(deps, `[[`, "stylesheet")))
})

test_that("tiles widget payload keeps the tile order, labels and KRI columns (#347)", {
  dfTiles <- rm_ParticipantTiles(rm_Classify(rm_Fixture()))
  w <- Widget_RepeatMeasurementsTiles(dfTiles, strLabel = "nd", nPageSize = 10)
  x <- w$x
  dfPayload <- jsonlite::fromJSON(x$tiles)
  expect_equal(unique(dfPayload$subjid), c("A", "B", "D", "C", "E"))
  expect_true(all(c("subjid", "vital", "column", "flag", "label_rate", "label_nd", "label_both") %in% names(dfPayload)))
  expect_equal(dfPayload$label_nd[dfPayload$subjid == "D" & dfPayload$vital == "weight"], "1/4")
  dfColumns <- jsonlite::fromJSON(x$columns)
  expect_equal(dfColumns$column, c("WT", "HR", "SBP", "DBP", "RR", "Temp"))
  expect_equal(dfColumns$metric, paste0("kri0020", letters[1:6]))
  expect_equal(x$label, "nd")
  expect_equal(x$pageSize, 10)
  expect_equal(x$colors$Red, rm_FlagColors()[["Red"]])
})

test_that("tiles widget rejects unknown labels and missing columns (#347)", {
  dfTiles <- rm_ParticipantTiles(rm_Classify(rm_Fixture()))
  expect_error(Widget_RepeatMeasurementsTiles(dfTiles, strLabel = "pct"))
  expect_error(Widget_RepeatMeasurementsTiles(dfTiles[setdiff(names(dfTiles), "label_both")]), "label_both")
})
