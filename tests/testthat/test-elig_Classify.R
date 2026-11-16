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

test_that("pilot mode is triggered by the edc_query column and Ineligible wins (#371)", {
  dfIn <- elig_Fixture(bPilot = TRUE)
  df <- elig_ClassifyParticipants(dfIn)

  expect_equal(elig_Mode(dfIn), "pilot")
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

test_that("EDC PD is NA when the source is not delivered (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE))
  expect_true(all(is.na(df$flag_edc_pd)))
  expect_false(elig_HasSource(df, "flag_edc_pd"))
  expect_true(elig_HasSource(df, "flag_edc_query"))
  expect_equal(df$status[df$subjid == "P06"], ELIG_NO_RISK)
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

test_that("criterion codes are split and typed as Inclusion or Exclusion (#371)", {
  df <- elig_CriteriaLong(elig_ClassifyParticipants(elig_Fixture()))
  expect_equal(nrow(df), 3)
  expect_setequal(df$criterion, c("incl1", "excl2"))
  expect_equal(unique(df$type[df$criterion == "incl1"]), "Inclusion")
  expect_equal(unique(df$type[df$criterion == "excl2"]), "Exclusion")
  expect_equal(elig_CriterionType(c("I001", "E010", "INCL3", "x9")), c("Inclusion", "Exclusion", "Inclusion", "Other"))
})

test_that("the history slices Potentially Ineligible as the risk numerator minus qtl0001 (#371)", {
  rows <- elig_TrendRows(elig_FixtureResults(bRisk = TRUE))
  oct <- rows[rows$GroupID == "2026-10-01", ]
  expect_equal(oct$n[oct$Status == ELIG_INELIGIBLE], 3)
  expect_equal(oct$n[oct$Status == ELIG_POTENTIAL], 1)
  expect_equal(oct$n[oct$Status == ELIG_NO_RISK], 3)
  # September has no risk metric: no Status over Time bar for it.
  expect_false("2026-09-01" %in% rows$GroupID)
  expect_equal(nrow(elig_TrendRows(elig_FixtureResults())), 0)
})
