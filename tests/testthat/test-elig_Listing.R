test_that("the listing has flagged participants only, with basic or pilot columns (#371)", {
  basic <- elig_ListingData(elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups()))
  expect_equal(nrow(basic), 4)
  expect_false("Source" %in% names(basic))
  expect_equal(
    names(basic),
    c("Country", "Site", "Investigator Name", "Participant ID", "Eligibility Status", "PD", "EDC eCRF", "Which I/E")
  )
  expect_false(any(grepl("Potentially", unlist(basic))))

  pilot <- elig_ListingData(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE)))
  expect_true(all(c("Important PD", "Non-important PD", "EDC Query", "EDC PD") %in% names(pilot)))
  expect_false("PD" %in% names(pilot))
  expect_true(all(pilot$`EDC PD` == "N/A"))
  expect_equal(pilot$`Eligibility Status`[pilot$`Participant ID` == "P03"], ELIG_POTENTIAL)
})

test_that("participant records come from level 2 records, else from the PD dates/terms and criteria (#371)", {
  basic <- elig_ParticipantRecords(elig_ClassifyParticipants(elig_Fixture()))
  pd <- basic[basic$subjid == "P02", ]
  expect_equal(pd$source, rep("Protocol Deviation", 2))
  expect_equal(pd$Date, c("2026-01-02", "2026-02-03"))
  expect_equal(pd$Description, c("PD one", "PD two"))
  expect_equal(basic$Criterion[basic$subjid == "P01"], c("incl1", "excl2"))
  expect_false("P03" %in% basic$subjid)

  pilot <- elig_ParticipantRecords(
    elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE)),
    elig_FixtureRecords()
  )
  q <- pilot[pilot$subjid == "P03", ]
  expect_equal(c(q$source, q$ID, q$Date), c("EDC Query", "Q1", "2026-10-01"))
  expect_false(any(c("studyid", "record_id", "record_date") %in% names(pilot)))
})

test_that("the expanded row shows one table per source with only the fields used (#371)", {
  basic <- elig_ParticipantRecords(elig_ClassifyParticipants(elig_Fixture()))
  html <- as.character(elig_ParticipantDetail("P01", basic))
  expect_match(html, "EDC eCRF (2)", fixed = TRUE)
  expect_no_match(html, "Protocol Deviation")

  pilot <- elig_ParticipantRecords(
    elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE)),
    elig_FixtureRecords()
  )
  html <- as.character(elig_ParticipantDetail("P03", pilot))
  expect_match(html, "EDC Query (1)", fixed = TRUE)
  expect_match(html, "Please check I/E", fixed = TRUE)
  expect_no_match(html, "Description")
})

test_that("the CSV export adds one details column per source, one Field: value per line (#371)", {
  dfElig <- elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE))
  recs <- elig_ParticipantRecords(dfElig, elig_FixtureRecords())
  ex <- elig_ExportData(elig_ListingData(dfElig), recs, ELIG_RECORD_SOURCES)
  expect_equal(tail(names(ex), 4), paste(ELIG_RECORD_SOURCES, "details"))
  row <- function(id) ex[ex$`Participant ID` == id, ]
  expect_equal(row("P02")$`Protocol Deviation details`, "ID: PD-9\nDate: 2026-01-02\nDescription: PD one")
  expect_equal(
    row("P01")$`EDC Query details`,
    "ID: Q2\nDate: 2026-09-01\nFolder: ENROLL\nForm: IE\nQueryText: Check criterion\nStatus: Answered"
  )
  expect_equal(row("P01")$`EDC PD details`, "")

  dfBasic <- elig_ClassifyParticipants(elig_Fixture())
  basic <- elig_ExportData(elig_ListingData(dfBasic), elig_ParticipantRecords(dfBasic), "Protocol Deviation")
  expect_equal(tail(names(basic), 1), "Protocol Deviation details")
  expect_equal(
    basic$`Protocol Deviation details`[basic$`Participant ID` == "P02"],
    "Date: 2026-01-02\nDescription: PD one\n\nDate: 2026-02-03\nDescription: PD two"
  )
})

test_that("overview cards follow the mode (#371)", {
  basic <- as.character(elig_OverviewCards(elig_ClassifyParticipants(elig_Fixture())))
  expect_match(basic, ELIG_NO_RISK, fixed = TRUE)
  expect_no_match(basic, "Potentially", fixed = TRUE)

  pilot <- as.character(elig_OverviewCards(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE)), bPilot = TRUE))
  expect_match(pilot, "Total risk", fixed = TRUE)
  expect_match(pilot, ELIG_POTENTIAL, fixed = TRUE)
})
