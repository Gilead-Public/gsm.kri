test_that("basic mode keeps two statuses and never yields Potentially Ineligible (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups())

  expect_equal(elig_Mode(elig_Fixture()), "basic")
  expect_setequal(unique(df$status), c(ELIG_INELIGIBLE, ELIG_NO_RISK))
  expect_equal(sum(df$status == ELIG_INELIGIBLE), 4)
  expect_false(any(df$status == ELIG_POTENTIAL))
})

test_that("Ineligible is Source != 'Neither' whatever the Source wording (#371)", {
  df <- elig_Fixture()
  df$Source[df$Source == "Eligibility IPD only"] <- "Some future wording"
  out <- elig_ClassifyParticipants(df)
  expect_equal(out$status[out$subjid == "P05"], ELIG_INELIGIBLE)
  expect_equal(out$status[out$subjid == "P03"], ELIG_NO_RISK)
})

test_that("pilot mode is set by strMode, not by the edc_query column, and Ineligible wins (#371)", {
  dfIn <- elig_Fixture(bPilot = TRUE)
  df <- elig_ClassifyParticipants(dfIn, strMode = "pilot")

  expect_equal(elig_Mode(dfIn), "basic")
  expect_equal(elig_Mode(dfIn, "pilot"), "pilot")
  expect_false(ELIG_POTENTIAL %in% elig_ClassifyParticipants(dfIn)$status)
  status <- stats::setNames(df$status, df$subjid)
  expect_equal(status[["P01"]], ELIG_INELIGIBLE)
  expect_equal(status[["P03"]], ELIG_POTENTIAL)
  expect_equal(status[["P06"]], ELIG_POTENTIAL)
  expect_equal(status[["P07"]], ELIG_NO_RISK)
})

test_that("flag sources come from the flag columns, not from Source (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  flag <- function(id, col) df[[col]][df$subjid == id]

  expect_equal(flag("P01", "flag_ecrf"), "Y")
  expect_equal(flag("P01", "flag_pd"), "N")
  expect_equal(flag("P04", "flag_ecrf"), "Y")
  expect_equal(flag("P04", "flag_pd"), "Y")
  expect_equal(flag("P05", "flag_pd"), "Y")

  # gsm.mapping's EXCLUSION has no pd_violation: the PD terms flag the PD.
  dfMapping <- dplyr::select(elig_Fixture(), -"pd_violation")
  out <- elig_ClassifyParticipants(dfMapping)
  expect_equal(out$flag_pd[out$subjid == "P02"], "Y")
  expect_equal(out$flag_pd[out$subjid == "P01"], "N")
})

test_that("a PD that is neither important nor non-important keeps the PD flag (#371)", {
  dfExclusion <- elig_Fixture(bPilot = TRUE)
  dfExclusion$pd_nonimportant[dfExclusion$subjid == "P05"] <- "N"
  df <- elig_ClassifyParticipants(dfExclusion)
  expect_equal(df$flag_pd[df$subjid == "P05"], "Y")
  expect_true("flag_pd" %in% names(elig_Sources(df)))
  expect_equal(elig_ListingData(df)$PD[elig_ListingData(df)$`Participant ID` == "P05"], "Y")

  # Every PD classified: the split replaces the PD flag.
  expect_false("flag_pd" %in% names(elig_Sources(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE), strMode = "pilot"))))
})

test_that("EDC PD is NA when the source is not delivered (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE), strMode = "pilot")
  expect_true(all(is.na(df$flag_edc_pd)))
  expect_false(elig_HasSource(df, "flag_edc_pd"))
  expect_true(elig_HasSource(df, "flag_edc_query"))
  expect_equal(df$status[df$subjid == "P06"], ELIG_NO_RISK)
})

test_that("EDC Query is NA when the source is not delivered (#371)", {
  dfIn <- elig_Fixture(bPilot = TRUE)
  dfIn$edc_query <- NA_character_
  df <- elig_ClassifyParticipants(dfIn, strMode = "pilot")
  expect_true(all(is.na(df$flag_edc_query)))
  expect_false(elig_HasSource(df, "flag_edc_query"))
  expect_equal(df$status[df$subjid == "P03"], ELIG_NO_RISK)
  expect_equal(df$status[df$subjid == "P06"], ELIG_POTENTIAL)
})

test_that("pilot mode falls back to basic with a warning when neither EDC source has data (#371)", {
  dfIn <- elig_Fixture(bPilot = TRUE)
  dfIn$edc_query <- NA_character_
  dfIn$edc_pd <- NA_character_
  expect_warning(expect_equal(elig_Mode(dfIn, "pilot"), "basic"), "basic")
  expect_warning(expect_equal(elig_Mode(elig_Fixture(), "pilot"), "basic"), "basic")

  dfIn$edc_pd <- "N"
  expect_no_warning(expect_equal(elig_Mode(dfIn, "pilot"), "pilot"))
  expect_error(elig_Mode(dfIn, "full"))
})

test_that("investigator names come from Site groups and are blank without them (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups())
  inv <- stats::setNames(df$investigator, df$subjid)
  expect_equal(inv[["P01"]], "Ada Lovelace")
  expect_equal(inv[["P04"]], "Curie")

  dfStudyOnly <- elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups(bSites = FALSE))
  expect_true(all(is.na(dfStudyOnly$investigator)))
  expect_true(all(is.na(elig_ClassifyParticipants(elig_Fixture())$investigator)))
})

test_that("missing country and site show as Unknown (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  expect_equal(df$country[df$subjid == "P08"], "Unknown")
  expect_equal(df$invid[df$subjid == "P08"], "Unknown")
})

test_that("criterion type comes from iecat_concat (#371)", {
  df <- elig_CriteriaLong(elig_ClassifyParticipants(elig_Fixture()))
  expect_equal(nrow(df), 3)
  expect_setequal(df$criterion, c("incl1", "excl2"))
  expect_equal(unique(df$type[df$criterion == "incl1"]), "Inclusion")
  expect_equal(unique(df$type[df$criterion == "excl2"]), "Exclusion")
  expect_equal(
    elig_CriterionType(c("IN", "ex", "Inclusion", "Z", NA)),
    c("Inclusion", "Exclusion", "Inclusion", "Not classified", "Not classified")
  )
})

test_that("criteria are Not classified without iecat_concat, never typed from the code (#371)", {
  df <- elig_CriteriaLong(elig_ClassifyParticipants(elig_Fixture(bIecat = FALSE)))
  expect_equal(unique(df$type), "Not classified")

  dfCode <- elig_Fixture()
  dfCode$ietestcd_concat[dfCode$subjid == "P04"] <- "IE_EXC01"
  dfCode$iecat_concat[dfCode$subjid == "P04"] <- NA
  long <- elig_CriteriaLong(elig_ClassifyParticipants(dfCode))
  expect_equal(long$type[long$criterion == "IE_EXC01"], "Not classified")
})

test_that("a participant with misaligned iecat_concat is Not classified (#371)", {
  df <- elig_Fixture()
  df$iecat_concat[df$subjid == "P01"] <- "IN"
  long <- elig_CriteriaLong(elig_ClassifyParticipants(df))
  expect_equal(long$type[long$subjid == "P01"], c("Not classified", "Not classified"))
  expect_equal(long$type[long$subjid == "P04"], "Exclusion")
})

test_that("status counts give the snapshot's participants per study and status, as the report classifies them (#371)", {
  pilot <- elig_StatusCounts(elig_Fixture(bPilot = TRUE), strMode = "pilot")
  expect_equal(names(pilot), c("GroupLevel", "GroupID", "Status", "n"))
  expect_equal(unique(pilot$GroupLevel), "Study")
  n <- stats::setNames(pilot$n, pilot$Status)
  expect_equal(n[[ELIG_INELIGIBLE]], 4L)
  expect_equal(n[[ELIG_POTENTIAL]], 2L)
  expect_equal(n[[ELIG_NO_RISK]], 2L)

  basic <- elig_StatusCounts(elig_Fixture())
  expect_equal(basic$Status, c(ELIG_INELIGIBLE, ELIG_NO_RISK))
  expect_equal(sum(basic$n), 8L)
})

test_that("Status over Time has one bar per snapshot of the study's status history (#371)", {
  rows <- elig_TrendRows(elig_FixtureStatusHistory())
  expect_equal(unique(rows$GroupID), c("2026-10-01", "2026-11-01"))
  oct <- rows[rows$GroupID == "2026-10-01", ]
  expect_equal(oct$Status, c(ELIG_INELIGIBLE, ELIG_POTENTIAL, ELIG_NO_RISK))
  expect_equal(oct$n, c(3L, 1L, 3L))

  # Only study rows draw the chart, and a zero count draws no segment.
  dfHistory <- elig_FixtureStatusHistory()
  dfHistory$n[2] <- 0L
  dfHistory <- dplyr::bind_rows(dfHistory, dplyr::mutate(dfHistory[1, ], GroupLevel = "Site", GroupID = "0X001"))
  expect_equal(nrow(elig_TrendRows(dfHistory)), 5)
  expect_equal(nrow(elig_TrendRows(NULL)), 0)
})
