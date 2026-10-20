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
})

test_that("dosed statuses follow treatment completion in stack order and colour (#332)", {
  vColors <- ipc_StatusColors()
  expect_identical(
    names(vColors)[c(1, 5:8)],
    c(
      "Treatment complete per protocol",
      "Premature treatment discontinuation",
      "Potential premature treatment discontinuation",
      "Unrecognized status",
      "Treatment ongoing"
    )
  )
  expect_equal(
    unname(vColors[c(
      "Treatment complete per protocol",
      "Premature treatment discontinuation",
      "Potential premature treatment discontinuation",
      "Unrecognized status",
      "Treatment ongoing"
    )]),
    c("#1E7B3C", "#111111", "#5F6B7A", "#9AA4B2", "#8CCB7E")
  )
})

test_that("every fixture participant lands in its status (#320, #332)", {
  df <- classify_fixture()
  expected <- c(
    P01 = "Treatment ongoing",
    P02 = "Treatment complete per protocol",
    P03 = "Potential IP non-starter - within window",
    P04 = "Potential IP non-starter - outside window",
    P05 = "Confirmed IP non-starter",
    P06 = "Premature treatment discontinuation",
    P07 = "Premature treatment discontinuation",
    P08 = "Premature treatment discontinuation",
    P09 = "Potential premature treatment discontinuation",
    P10 = "Treatment ongoing",
    P11 = "Unrecognized status",
    P12 = "Potential IP non-starter - within window",
    P13 = "Unrecognized status",
    P14 = "Unrecognized status",
    P15 = "Unrecognized status",
    P16 = "Treatment ongoing",
    P17 = "Potential IP non-starter - within window",
    P18 = "Confirmed IP non-starter",
    P19 = "Treatment ongoing",
    P20 = "Treatment ongoing",
    P21 = "Potential IP non-starter - outside window",
    P22 = "Premature treatment discontinuation",
    P23 = "Treatment ongoing",
    P24 = "Confirmed IP non-starter",
    P25 = "Treatment complete per protocol",
    P26 = "Premature treatment discontinuation",
    P27 = "Potential premature treatment discontinuation",
    P28 = "Treatment ongoing",
    P29 = "Unrecognized status"
  )
  expect_equal(nrow(df), 29)
  expect_equal(
    stats::setNames(as.character(df$status), df$subjid)[names(expected)],
    expected
  )
  expect_identical(levels(df$status), names(ipc_StatusColors()))
})

test_that("each drv_drg_completion value maps to one dosed status (#332)", {
  df <- classify_fixture()
  expect_equal(status_of(df, "P06"), "Premature treatment discontinuation")
  expect_equal(status_of(df, "P27"), "Potential premature treatment discontinuation")
  expect_equal(status_of(df, "P25"), "Treatment complete per protocol")
  expect_equal(status_of(df, "P28"), "Treatment ongoing")
})

test_that("NA and blank outcomes alike give Treatment ongoing (#332)", {
  df <- classify_fixture()
  expect_equal(status_of(df, "P01"), "Treatment ongoing")
  expect_equal(status_of(df, "P19"), "Treatment ongoing")
})

test_that("study completion changes neither Treatment complete per protocol nor Treatment ongoing (#332)", {
  df <- classify_fixture()
  # P02 and P20 have a completion record with compyn Y; P25 and P01 have none.
  expect_equal(status_of(df, "P02"), status_of(df, "P25"))
  expect_equal(status_of(df, "P20"), status_of(df, "P01"))
  expect_true(is.na(df$event_dt[df$subjid == "P20"]))
  expect_equal(df$consent_withdrawn[df$subjid == "P20"], "Y")
})

test_that("every dosed status is dated by the discontinuation date, else sits on the diagonal (#332)", {
  df <- classify_fixture()
  row <- function(id) df[df$subjid == id, ]
  dated <- c(
    P06 = "2026-04-10",
    P27 = "2026-05-20",
    P25 = "2026-05-15",
    P28 = "2026-04-01"
  )
  for (id in names(dated)) {
    expect_equal(row(id)$event_dt, as.Date(dated[[id]]), label = id)
  }
  for (id in c("P26", "P09", "P02", "P01")) {
    expect_true(is.na(row(id)$event_dt), label = id)
    expect_equal(row(id)$days_to_event, row(id)$days_since_enrl, label = id)
  }
})

test_that("a Confirmed non-starter's event is the earliest non-blank completion record (#320)", {
  df <- classify_fixture()
  expect_equal(df$event_dt[df$subjid == "P05"], as.Date("2026-03-15"))
  expect_equal(df$consent_withdrawn[df$subjid == "P05"], "Y")
})

test_that("day counts include the enrollment day (#320, #332)", {
  df <- classify_fixture()
  p22 <- df[df$subjid == "P22", ]
  expect_equal(p22$days_to_event, 1L)
  expect_equal(p22$days_to_first_dose, 1L)
  expect_equal(p22$days_since_enrl, 30L)
  p06 <- df[df$subjid == "P06", ]
  expect_equal(p06$days_since_enrl, 167L)
  expect_equal(p06$days_to_event, 86L)
  # No event: the event count is the snapshot count, so the point is on the diagonal.
  p01 <- df[df$subjid == "P01", ]
  expect_equal(p01$days_to_event, p01$days_since_enrl)
})

test_that("each data conflict warns and names the participant (#320, #332)", {
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
  expect_match(w, "drv_drg_completion value; the value is ignored.*P12", all = FALSE)
  expect_match(w, "not Y, N or Potential No.*P29", all = FALSE)
  expect_match(w, "not a report status label.*P14", all = FALSE)
  expect_match(w, "No event date.*P18", all = FALSE)
  expect_match(w, "No enrollment date.*P23", all = FALSE)
  expect_match(w, "before enrollment or after the snapshot.*P24", all = FALSE)
})

test_that("a blank or NA outcome on a not-dosed participant does not warn (#332)", {
  f <- ipc_Fixture()
  w <- testthat::capture_warnings(ipc_ClassifyParticipants(
    f$Mapped_IPNS,
    f$Mapped_SUBJ,
    f$Mapped_STUDCOMP,
    ipc_FixtureSnapshotDate
  ))
  ignored <- grep("drv_drg_completion value", w, value = TRUE)
  expect_length(ignored, 1)
  expect_no_match(ignored, "P03|P05")
})

test_that("no dosed status raises the No event date warning (#332)", {
  f <- ipc_Fixture()
  w <- testthat::capture_warnings(ipc_ClassifyParticipants(
    f$Mapped_IPNS,
    f$Mapped_SUBJ,
    f$Mapped_STUDCOMP,
    ipc_FixtureSnapshotDate
  ))
  no_date <- grep("No event date", w, value = TRUE)
  expect_length(no_date, 1)
  # Only the Confirmed non-starter without a completion record.
  expect_no_match(no_date, "P01|P02|P09|P20|P26")
  expect_match(no_date, "P18")
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

test_that("without drv_drg_completion every dosed participant is Unrecognized; not-dosed statuses are unchanged (#332)", {
  df <- classify_fixture(bPTD = FALSE)
  full <- classify_fixture()
  bDosed <- df$dosed %in% "Y"
  expect_true(all(df$status[bDosed] == "Unrecognized status"))
  expect_equal(df$status[!bDosed], full$status[!bDosed])
  expect_true(all(df$drg_completion == ""))
})

test_that("drg_completion shows the delivered value for dosed participants only (#332)", {
  df <- classify_fixture()
  value <- stats::setNames(df$drg_completion, df$subjid)
  expect_equal(
    unname(value[c("P06", "P09", "P02", "P01", "P19", "P29", "P12", "P03")]),
    c("N", "Potential No", "Y", "", "", "Maybe", "", "")
  )
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

test_that("study_complete is Y or N from the completion records, else blank (#332)", {
  df <- classify_fixture()
  value <- stats::setNames(df$study_complete, df$subjid)
  # P20 has N, Y and Y records: any Y wins. P01 and P03 have no record.
  expect_equal(
    unname(value[c("P02", "P20", "P19", "P05", "P01", "P03")]),
    c("Y", "Y", "N", "N", "", "")
  )
  studcomp <- data.frame(
    subjid = c("S1", "S2", "S3", "S4", "S4", "S5"),
    compyn = c(NA, "", " y", "N", "Y", "n"),
    compreas = NA,
    mincreated_dts = as.POSIXct("2026-05-01", tz = "UTC")
  )
  summary <- ipc_StudCompSummary(studcomp)
  expect_equal(
    summary$study_complete[match(paste0("S", 1:5), summary$subjid)],
    c("", "", "Y", "Y", "N")
  )
})

test_that("a completion timestamp keeps its own calendar date (#320, #332)", {
  studcomp <- data.frame(
    subjid = "S1",
    compyn = "Y",
    compreas = NA,
    mincreated_dts = as.POSIXct("2026-05-01 23:30:00", tz = "America/New_York")
  )
  expect_equal(ipc_StudCompSummary(studcomp)$confirm_dt, as.Date("2026-05-01"))
  expect_false("complete_dt" %in% names(ipc_StudCompSummary(studcomp)))
})

test_that("no study completion data leaves every dosed status unchanged (#320, #332)", {
  f <- ipc_Fixture()
  full <- classify_fixture()
  for (studcomp in list(NULL, f$Mapped_STUDCOMP[0, ])) {
    df <- suppressWarnings(ipc_ClassifyParticipants(
      f$Mapped_IPNS,
      f$Mapped_SUBJ,
      studcomp,
      ipc_FixtureSnapshotDate
    ))
    bDosed <- df$dosed %in% "Y"
    expect_equal(df$status[bDosed], full$status[bDosed])
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
