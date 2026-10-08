# Edge-case fixture for the IP Compliance report: one participant per case.
# Four countries (Japan with two sites, "Unknown" from missing values) and five
# sites. "PL-01 (B)" carries regex metacharacters for the listing's exact-match
# filter.
ipc_FixtureSnapshotDate <- as.Date("2026-06-30")

ipc_Fixture <- function(bPTD = TRUE) {
  p <- function(
    subjid,
    country,
    invid,
    dosed,
    ord,
    label = NA,
    enrl = NA,
    first_dose = NA,
    ptd = NA,
    reason = NA,
    kit = "Y",
    raw = NA
  ) {
    data.frame(
      subjid = subjid,
      country = country,
      invid = invid,
      drv_ip_dosed = dosed,
      ipns_status_ord = as.integer(ord),
      ipns_status = label,
      drv_ip_nonstarter_status = raw,
      drv_enrollment_dt = as.Date(enrl),
      drv_ip_first_dose_dt = as.Date(first_dose),
      drv_kit_assigned = kit,
      drv_treatment_discontinuation_dt = as.Date(ptd),
      drv_premature_discontinuation_reason = reason,
      stringsAsFactors = FALSE
    )
  }
  within <- "Potential IP non-starter - within window"
  outside <- "Potential IP non-starter - outside window"
  confirmed <- "Confirmed IP non-starter"
  # fmt: skip
  rows <- rbind(
    # Ongoing: dosed, no discontinuation, no completion record.
    p("P01", "Japan", "JP01", "Y", 0, "Dosed", "2026-01-10", "2026-01-12", raw = "Dosed"),
    # Study complete.
    p("P02", "Japan", "JP01", "Y", 0, "Dosed", "2026-01-05", "2026-01-06", raw = "Dosed"),
    p("P03", "Japan", "JP02", "N", 1, within, "2026-06-20", kit = "N", raw = "Potential Non-Starter within window"),
    p("P04", "Poland", "PL-01 (B)", "N", 2, outside, "2026-04-01", raw = "Potential Non-Starter outside window"),
    # Confirmed with consent withdrawn.
    p("P05", "Canada", "CA01", "N", 3, confirmed, "2026-02-01", kit = "N", raw = "Confirmed Non-Starter"),
    # Discontinued and completed: discontinuation takes precedence.
    p("P06", "Japan", "JP01", "Y", 0, "Dosed", "2026-01-15", "2026-01-16", "2026-04-10", "Adverse Event", raw = "Dosed"),
    # Discontinued with no reason: "Not yet recorded".
    p("P07", "Japan", "JP02", "Y", 0, "Dosed", "2026-02-10", "2026-02-11", "2026-03-01", raw = "Dosed"),
    # Two reasons, the second after a space.
    p("P08", "Poland", "PL-01 (B)", "Y", 0, "Dosed", "2026-01-20", "2026-01-21", "2026-05-05", "Adverse Event, Physician Decision", raw = "Dosed"),
    # Reason without a date: not discontinued, reason not counted.
    p("P09", "Canada", "CA01", "Y", 0, "Dosed", "2026-03-01", "2026-03-02", reason = "Lack of Efficacy", raw = "Dosed"),
    # Dosed with a not-dosed status: the dosed flag wins.
    p("P10", "Canada", "CA01", "Y", 2, outside, "2026-02-15", "2026-02-16", raw = "Potential Non-Starter outside window"),
    # Not dosed with the Dosed status: Unrecognized.
    p("P11", "Japan", "JP02", "N", 0, "Dosed", "2026-03-10", raw = "Dosed"),
    # Not dosed with a discontinuation date: the date is ignored.
    p("P12", "Poland", "PL-01 (B)", "N", 1, within, "2026-06-15", ptd = "2026-06-25", raw = "Potential Non-Starter within window"),
    # Status value the mapping does not recognise: both columns NA.
    p("P13", "Canada", "CA01", "N", NA, NA, "2026-05-01", raw = "Pending review"),
    # Drifted label: ordinal 2 with a string outside the colour map.
    p("P14", "Japan", "JP01", "N", 2, "Potential non-starter - outside window (legacy)", "2026-04-05", raw = "Potential Non-Starter outside window"),
    # Dosed flag that is neither Y nor N.
    p("P15", "Japan", "JP02", "U", 0, "Dosed", "2026-02-20", raw = "Dosed"),
    # Duplicate participant: the first row (Ongoing, JP01) is kept.
    p("P16", "Japan", "JP01", "Y", 0, "Dosed", "2026-02-01", "2026-02-03", raw = "Dosed"),
    p("P16", "Canada", "CA01", "N", 3, confirmed, "2026-02-01", raw = "Confirmed Non-Starter"),
    # Missing site and country: both "Unknown".
    p("P17", "", NA, "N", 1, within, "2026-06-25", raw = "Potential Non-Starter within window"),
    # Confirmed with no completion record: no event date.
    p("P18", "Japan", "JP01", "N", 3, confirmed, "2026-03-20", raw = "Confirmed Non-Starter"),
    # Dosed, left the study (compyn N) without a discontinuation date: Ongoing.
    p("P19", "Poland", "PL-01 (B)", "Y", 0, "Dosed", "2026-02-25", "2026-03-01", raw = "Dosed"),
    # Three completion records: any Y completes, the earliest Y dates it.
    p("P20", "Canada", "CA01", "Y", 0, "Dosed", "2026-01-25", "2026-01-26", raw = "Dosed"),
    # Kit value missing.
    p("P21", "Japan", "JP02", "N", 2, outside, "2026-04-15", kit = NA, raw = "Potential Non-Starter outside window"),
    # Enrollment, first dose and discontinuation on one day: every count is 1.
    p("P22", "Canada", "CA01", "Y", 0, "Dosed", "2026-06-01", "2026-06-01", "2026-06-01", "Withdrawal by Subject, ", raw = "Dosed"),
    # No enrollment date: no day counts, no scatter point.
    p("P23", "Japan", "JP01", "Y", 0, "Dosed", NA, "2026-03-05", raw = "Dosed"),
    # Confirmed with a completion record dated before enrollment.
    p("P24", "Poland", "PL-01 (B)", "N", 3, confirmed, "2026-03-10", raw = "Confirmed Non-Starter")
  )
  rows$studyid <- "ST01"

  # fmt: skip
  studcomp <- data.frame(
    studyid = "ST01",
    subjid   = c("P02", "P05", "P06", "P19", "P20", "P20", "P20", "P24"),
    compyn   = c("Y", "N", "Y", "N", "N", "Y", "Y", "N"),
    compreas = c(NA, "Withdrew Consent", NA, "Lost to Follow-up", "Withdrew Consent", NA, NA, "Physician Decision"),
    mincreated_dts = as.POSIXct(
      paste(c("2026-05-01", "2026-03-15", "2026-05-20", "2026-04-01", "2026-03-01", "2026-05-10", "2026-04-20", "2026-03-01"), "09:00:00"),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )

  ipns_cols <- c(
    "studyid",
    "subjid",
    "invid",
    "country",
    "drv_enrollment_dt",
    "drv_ip_dosed",
    "drv_ip_first_dose_dt",
    "drv_ip_nonstarter_status",
    "drv_kit_assigned",
    "ipns_status_ord",
    "ipns_status"
  )
  subj_cols <- c(
    "studyid",
    "subjid",
    "invid",
    "country",
    "drv_ip_dosed",
    "drv_kit_assigned",
    if (bPTD) {
      c(
        "drv_treatment_discontinuation_dt",
        "drv_premature_discontinuation_reason"
      )
    }
  )
  list(
    Mapped_IPNS = tibble::as_tibble(rows[ipns_cols]),
    Mapped_SUBJ = tibble::as_tibble(rows[subj_cols]),
    Mapped_STUDCOMP = tibble::as_tibble(studcomp)
  )
}

ipc_classified <- function(bPTD = TRUE) {
  f <- ipc_Fixture(bPTD)
  suppressWarnings(ipc_ClassifyParticipants(
    f$Mapped_IPNS,
    f$Mapped_SUBJ,
    f$Mapped_STUDCOMP,
    ipc_FixtureSnapshotDate
  ))
}
