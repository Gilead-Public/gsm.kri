test_that("the listing has flagged participants only, with basic or pilot columns (#113)", {
  basic <- elig_ListingData(elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups()))
  expect_equal(nrow(basic), 4)
  expect_false("Source" %in% names(basic))
  expect_equal(
    names(basic)[1:8],
    c("Country", "Site", "Investigator Name", "Participant ID", "Eligibility Status", "PD", "EDC eCRF", "Which I/E")
  )
  expect_equal(basic$`PD Term 2`[basic$`Participant ID` == "P02"], "PD two")
  expect_false(any(grepl("Potentially", unlist(basic))))

  pilot <- elig_ListingData(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE)))
  expect_true(all(c("Important PD", "Non-important PD", "EDC Query", "EDC PD") %in% names(pilot)))
  expect_false("PD" %in% names(pilot))
  expect_true(all(pilot$`EDC PD` == "N/A"))
  expect_equal(pilot$`Eligibility Status`[pilot$`Participant ID` == "P03"], ELIG_POTENTIAL)
})

test_that("the deep dive lists records per source, blank when none (#113)", {
  dfElig <- elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE))
  dd <- elig_DeepDiveData(dfElig, elig_FixtureRecords())
  expect_equal(names(dd)[5:8], c("EDC eCRF", "Protocol Deviation", "EDC Query", "EDC PD"))
  expect_match(dd$`EDC Query`[dd$`Participant ID` == "P03"], "^\\[Q1\\] 2026-10-01\nFolder: ENROLL")
  expect_true(is.na(dd$`EDC eCRF`[dd$`Participant ID` == "P03"]))
  expect_match(dd$`EDC PD`[dd$`Participant ID` == "P06"], "^\\[D1\\]\n")
})

test_that("overview cards follow the mode (#113)", {
  basic <- as.character(elig_OverviewCards(elig_ClassifyParticipants(elig_Fixture())))
  expect_match(basic, ELIG_NO_RISK, fixed = TRUE)
  expect_no_match(basic, "Potentially", fixed = TRUE)

  pilot <- as.character(elig_OverviewCards(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE)), bPilot = TRUE))
  expect_match(pilot, "Total risk", fixed = TRUE)
  expect_match(pilot, ELIG_POTENTIAL, fixed = TRUE)
})
