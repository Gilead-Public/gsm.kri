test_that("the listing has the report columns in order (#320, #332)", {
  df <- ipc_ListingData(ipc_classified())
  expect_equal(
    names(df),
    c(
      "subjid",
      "invid",
      "country",
      "status",
      "kit_assigned",
      "first_dose_dt",
      "days_to_first_dose",
      "days_since_enrl",
      "days_to_event",
      "study_complete",
      "consent_withdrawn",
      "drg_completion",
      "ptd_reason",
      "dosed"
    )
  )
  expect_equal(nrow(df), 29)
  expect_equal(df$subjid[1:2], c("P02", "P25"))
})

test_that("the reason fills for both discontinuation statuses, else Not yet recorded (#332)", {
  df <- ipc_ListingData(ipc_classified())
  row <- function(id) df[df$subjid == id, ]
  expect_equal(row("P08")$ptd_reason, "Adverse Event, Physician Decision")
  expect_equal(row("P07")$ptd_reason, "Not yet recorded")
  expect_equal(row("P26")$ptd_reason, "Not yet recorded")
  expect_equal(row("P09")$ptd_reason, "Lack of Efficacy")
  expect_equal(row("P27")$ptd_reason, "Physician Decision")
  expect_equal(row("P25")$ptd_reason, "")
  expect_equal(row("P28")$ptd_reason, "")
})

test_that("Study Drug Completed per Protocol shows Y, N, Potential No or blank (#332)", {
  df <- ipc_ListingData(ipc_classified())
  value <- stats::setNames(df$drg_completion, df$subjid)
  expect_equal(
    unname(value[c("P06", "P09", "P02", "P01", "P19", "P12")]),
    c("N", "Potential No", "Y", "", "", "")
  )
})

test_that("Study complete shows Y, N or blank next to Consent withdrawn (#332)", {
  df <- ipc_ListingData(ipc_classified())
  value <- stats::setNames(df$study_complete, df$subjid)
  expect_equal(unname(value[c("P02", "P19", "P01")]), c("Y", "N", ""))
  w <- ipc_Listing(df)
  expect_match(
    w$x$container,
    "<th>Study complete</th>\\s*<th>Consent withdrawn</th>"
  )
})

test_that("without drv_drg_completion the outcome and reason columns are blank (#332)", {
  df <- ipc_ListingData(ipc_classified(bPTD = FALSE))
  expect_true(all(df$drg_completion == ""))
  expect_true(all(df$ptd_reason == ""))
})

test_that("an unrecognised status shows the delivered value; a missing kit is blank (#320, #332)", {
  df <- ipc_ListingData(ipc_classified())
  expect_equal(
    df$status[df$subjid == "P13"],
    "Unrecognized status: Pending review"
  )
  expect_equal(df$status[df$subjid == "P29"], "Unrecognized status: Maybe")
  expect_equal(df$kit_assigned[df$subjid == "P21"], "")
})

test_that("the CSV exports every participant and hides the dosed column (#320, #332)", {
  w <- ipc_Listing(ipc_ListingData(ipc_classified()))
  expect_match(w$x$container, "<th>Study Drug Completed per Protocol</th>", fixed = TRUE)
  expect_no_match(w$x$container, "Premature treatment discontinuation", fixed = TRUE)
  expect_equal(w$elementId, "ipc-listing")
  button <- w$x$options$buttons[[1]]
  expect_equal(button$exportOptions$modifier$search, "none")
  expect_equal(button$exportOptions$columns, ":visible")
  # DT names every column itself; the report adds the hidden dosed column.
  defs <- w$x$options$columnDefs
  def_for <- function(name) Filter(function(d) identical(d$name, name), defs)
  expect_true(all(lengths(lapply(c("invid", "country", "dosed"), def_for)) > 0))
  hidden <- Filter(function(d) identical(d$visible, FALSE), defs)
  expect_length(hidden, 1)
  expect_equal(hidden[[1]]$targets, 13L)
})
