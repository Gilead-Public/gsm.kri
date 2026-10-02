test_that("the listing has the report columns in order (#320)", {
  df <- ipc_ListingData(ipc_classified(), TRUE)
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
      "consent_withdrawn",
      "ptd_flag",
      "ptd_reason",
      "dosed"
    )
  )
  expect_equal(nrow(df), 24)
  expect_equal(df$subjid[1:2], c("P02", "P20"))
})

test_that("discontinuation flag and reason fill only for discontinued participants (#320)", {
  df <- ipc_ListingData(ipc_classified(), TRUE)
  row <- function(id) df[df$subjid == id, ]
  expect_equal(row("P08")$ptd_reason, "Adverse Event, Physician Decision")
  expect_equal(row("P07")$ptd_reason, "Not yet recorded")
  expect_equal(row("P09")$ptd_reason, "")
  expect_equal(row("P06")$ptd_flag, "Y")
  expect_equal(row("P01")$ptd_flag, "N")
})

test_that("without discontinuation data the flag is blank (#320)", {
  df <- ipc_ListingData(ipc_classified(bPTD = FALSE), FALSE)
  expect_true(all(df$ptd_flag == ""))
  expect_true(all(df$ptd_reason == ""))
})

test_that("an unrecognised status shows the delivered value; a missing kit is blank (#320)", {
  df <- ipc_ListingData(ipc_classified(), TRUE)
  expect_equal(
    df$status[df$subjid == "P13"],
    "Unrecognized status: Pending review"
  )
  expect_equal(df$kit_assigned[df$subjid == "P21"], "")
})

test_that("the CSV exports every participant and hides the dosed column (#320)", {
  w <- ipc_Listing(ipc_ListingData(ipc_classified(), TRUE))
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
  expect_equal(hidden[[1]]$targets, 12L)
})
