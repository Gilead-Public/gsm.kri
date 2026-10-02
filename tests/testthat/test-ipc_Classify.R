classify_fixture <- function(bPTD = TRUE, ...) {
  f <- ipc_Fixture(bPTD)
  suppressWarnings(ipc_ClassifyParticipants(
    f$Mapped_IPNS,
    f$Mapped_SUBJ,
    f$Mapped_STUDCOMP,
    ipc_FixtureSnapshotDate
  ))
}
status_of <- function(df, id) as.character(df$status[df$subjid == id])

test_that("the not-dosed labels equal gsm.mapping's ipns_status values (#320)", {
  expect_identical(
    names(ipc_StatusColors())[2:4],
    c(
      "Potential IP non-starter - within window",
      "Potential IP non-starter - outside window",
      "Confirmed IP non-starter"
    )
  )
  expect_identical(
    names(ipc_StatusColors())[c(1, 5:7)],
    c(
      "Study complete",
      "Premature treatment discontinuation",
      "Unrecognized status",
      "Ongoing"
    )
  )
})

test_that("every fixture participant lands in its status (#320)", {
  df <- classify_fixture()
  expected <- c(
    P01 = "Ongoing",
    P02 = "Study complete",
    P03 = "Potential IP non-starter - within window",
    P04 = "Potential IP non-starter - outside window",
    P05 = "Confirmed IP non-starter",
    P06 = "Premature treatment discontinuation",
    P07 = "Premature treatment discontinuation",
    P08 = "Premature treatment discontinuation",
    P09 = "Ongoing",
    P10 = "Ongoing",
    P11 = "Unrecognized status",
    P12 = "Potential IP non-starter - within window",
    P13 = "Unrecognized status",
    P14 = "Unrecognized status",
    P15 = "Unrecognized status",
    P16 = "Ongoing",
    P17 = "Potential IP non-starter - within window",
    P18 = "Confirmed IP non-starter",
    P19 = "Ongoing",
    P20 = "Study complete",
    P21 = "Potential IP non-starter - outside window",
    P22 = "Premature treatment discontinuation",
    P23 = "Ongoing",
    P24 = "Confirmed IP non-starter"
  )
  expect_equal(nrow(df), 24)
  expect_equal(
    stats::setNames(as.character(df$status), df$subjid)[names(expected)],
    expected
  )
  expect_identical(levels(df$status), names(ipc_StatusColors()))
})

test_that("discontinuation takes precedence over study completion (#320)", {
  df <- classify_fixture()
  expect_equal(status_of(df, "P06"), "Premature treatment discontinuation")
  expect_equal(df$event_dt[df$subjid == "P06"], as.Date("2026-04-10"))
})

test_that("a dosed participant with compyn N and no discontinuation is Ongoing (#320)", {
  expect_equal(status_of(classify_fixture(), "P19"), "Ongoing")
})

test_that("several completion records: any Y completes and the earliest Y dates it (#320)", {
  df <- classify_fixture()
  expect_equal(status_of(df, "P20"), "Study complete")
  expect_equal(df$event_dt[df$subjid == "P20"], as.Date("2026-04-20"))
  expect_equal(df$consent_withdrawn[df$subjid == "P20"], "Y")
})

test_that("a Confirmed non-starter's event is the earliest non-blank completion record (#320)", {
  df <- classify_fixture()
  expect_equal(df$event_dt[df$subjid == "P05"], as.Date("2026-03-15"))
  expect_equal(df$consent_withdrawn[df$subjid == "P05"], "Y")
})

test_that("day counts include the enrollment day (#320)", {
  df <- classify_fixture()
  p22 <- df[df$subjid == "P22", ]
  expect_equal(p22$days_to_event, 1L)
  expect_equal(p22$days_to_first_dose, 1L)
  expect_equal(p22$days_since_enrl, 30L)
  p02 <- df[df$subjid == "P02", ]
  expect_equal(p02$days_since_enrl, 177L)
  expect_equal(p02$days_to_event, 117L)
  # No event: the event count is the snapshot count, so the point is on the diagonal.
  p01 <- df[df$subjid == "P01", ]
  expect_equal(p01$days_to_event, p01$days_since_enrl)
})

test_that("each data conflict warns and names the participant (#320)", {
  f <- ipc_Fixture()
  run <- function() {
    ipc_ClassifyParticipants(
      f$Mapped_IPNS,
      f$Mapped_SUBJ,
      f$Mapped_STUDCOMP,
      ipc_FixtureSnapshotDate
    )
  }
  w <- testthat::capture_warnings(run())
  expect_match(w, "duplicate rows.*P16", all = FALSE)
  expect_match(w, "not Y or N.*P15", all = FALSE)
  expect_match(w, "Dosed IP non-starter status.*P11", all = FALSE)
  expect_match(w, "dosed flag wins.*P10", all = FALSE)
  expect_match(w, "date is ignored.*P12", all = FALSE)
  expect_match(w, "not a report status label.*P14", all = FALSE)
  expect_match(w, "No event date.*P18", all = FALSE)
  expect_match(w, "No enrollment date.*P23", all = FALSE)
  expect_match(w, "before enrollment or after the snapshot.*P24", all = FALSE)
})

test_that("a warning names at most ten participants (#320)", {
  f <- ipc_Fixture()
  ipns <- f$Mapped_IPNS[rep(which(f$Mapped_IPNS$subjid == "P15"), 12), ]
  ipns$subjid <- sprintf("U%02d", 1:12)
  expect_warning(
    ipc_ClassifyParticipants(ipns, NULL, NULL, ipc_FixtureSnapshotDate),
    "U10 and 2 more"
  )
})

test_that("duplicates keep the first row (#320)", {
  df <- classify_fixture()
  expect_equal(sum(df$subjid == "P16"), 1)
  expect_equal(df$invid[df$subjid == "P16"], "JP01")
})

test_that("missing site and country read Unknown (#320)", {
  df <- classify_fixture()
  expect_equal(df$country[df$subjid == "P17"], "Unknown")
  expect_equal(df$invid[df$subjid == "P17"], "Unknown")
})

test_that("without discontinuation data, dosed is Ongoing or Study complete (#320)", {
  df <- classify_fixture(bPTD = FALSE)
  dosed <- as.character(df$status[df$dosed %in% "Y"])
  expect_setequal(unique(dosed), c("Ongoing", "Study complete"))
  expect_equal(status_of(df, "P06"), "Study complete")
  expect_true(all(df$ptd_flag == "N"))
})

test_that("a mapping without ipns_status or ipns_status_ord errors (#320)", {
  f <- ipc_Fixture()
  for (col in c("ipns_status", "ipns_status_ord")) {
    expect_error(
      ipc_ClassifyParticipants(
        f$Mapped_IPNS[setdiff(names(f$Mapped_IPNS), col)],
        NULL,
        NULL,
        ipc_FixtureSnapshotDate
      ),
      col
    )
  }
})

test_that("dSnapshotDate must be a single Date (#320)", {
  f <- ipc_Fixture()
  expect_error(
    ipc_ClassifyParticipants(f$Mapped_IPNS, dSnapshotDate = "2026-06-30"),
    "single Date"
  )
})

test_that("kit assignment falls back to Mapped_SUBJ (#320)", {
  f <- ipc_Fixture()
  ipns <- f$Mapped_IPNS[setdiff(names(f$Mapped_IPNS), "drv_kit_assigned")]
  df <- suppressWarnings(ipc_ClassifyParticipants(
    ipns,
    f$Mapped_SUBJ,
    f$Mapped_STUDCOMP,
    ipc_FixtureSnapshotDate
  ))
  expect_equal(df$kit_assigned, classify_fixture()$kit_assigned)
  expect_true(is.na(df$kit_assigned[df$subjid == "P21"]))
})

test_that("a completion timestamp keeps its own calendar date (#320)", {
  studcomp <- data.frame(
    subjid = "S1",
    compyn = "Y",
    compreas = NA,
    mincreated_dts = as.POSIXct("2026-05-01 23:30:00", tz = "America/New_York")
  )
  expect_equal(ipc_StudCompSummary(studcomp)$complete_dt, as.Date("2026-05-01"))
})

test_that("no study completion data leaves every dosed participant Ongoing or discontinued (#320)", {
  f <- ipc_Fixture()
  for (studcomp in list(NULL, f$Mapped_STUDCOMP[0, ])) {
    df <- suppressWarnings(ipc_ClassifyParticipants(
      f$Mapped_IPNS,
      f$Mapped_SUBJ,
      studcomp,
      ipc_FixtureSnapshotDate
    ))
    expect_false("Study complete" %in% df$status)
    expect_true(all(df$consent_withdrawn == "N"))
  }
})

test_that("zero enrolled participants give zero rows (#320)", {
  f <- ipc_Fixture()
  df <- ipc_ClassifyParticipants(
    f$Mapped_IPNS[0, ],
    f$Mapped_SUBJ[0, ],
    f$Mapped_STUDCOMP[0, ],
    ipc_FixtureSnapshotDate
  )
  expect_equal(nrow(df), 0)
  expect_identical(levels(df$status), names(ipc_StatusColors()))
})
