# Eligibility report fixtures. Source values are the real ones from both study
# families: gsm.mapping's EXCLUSION.yaml ("Eligibility PD only") and the study
# forks ("Eligibility IPD only"); the report must not depend on either.
elig_FixtureSnapshotDate <- as.Date("2026-11-01")

elig_Fixture <- function(bPilot = FALSE, bEdcPd = TRUE, bPDSplit = bPilot) {
  df <- tibble::tribble(
    ~studyid, ~invid, ~country, ~subjid, ~Source, ~ie_violation, ~pd_violation, ~ietestcd_concat, ~dvdtm, ~eligibility_criteria,
    "S1", "0X001", "US", "P01", "EDC I/E only", "Y", NA, "incl1,excl2", NA, NA,
    "S1", "0X001", "US", "P02", "Eligibility PD only", NA, "Y", NA, "2026-01-02;;;2026-02-03", "PD one;;;PD two",
    "S1", "0X001", "US", "P03", "Neither", NA, NA, NA, NA, NA,
    "S1", "0X002", "US", "P04", "Ineligible, Both Criteria", "Y", "Y", "excl2", "2026-03-04", "PD three",
    "S1", "0X003", "CA", "P05", "Eligibility IPD only", NA, "Y", NA, "2026-04-05", "PD four",
    "S1", "0X003", "CA", "P06", "Neither", NA, NA, NA, NA, NA,
    "S1", "0X003", "CA", "P07", "Neither", NA, NA, NA, NA, NA,
    "S1", NA, NA, "P08", "Neither", NA, NA, NA, NA, NA
  )
  if (bPDSplit) {
    df$pd_important <- c("N", "Y", "N", "N", "N", "N", "N", "N")
    df$pd_nonimportant <- c("N", "Y", "N", "Y", "Y", "N", "N", "N")
  }
  if (bPilot) {
    # P01 is Ineligible and has a query: Ineligible wins (2.3).
    df$edc_query <- c("Y", "N", "Y", "N", "N", "N", "N", "N")
    df$edc_pd <- if (bEdcPd) c("N", "N", "N", "N", "N", "Y", "N", "N") else NA_character_
  }
  df
}

elig_FixtureGroups <- function(bSites = TRUE) {
  study <- tibble::tibble(GroupID = "S1", GroupLevel = "Study", Param = "studyid", Value = "S1")
  if (!bSites) return(study)
  sites <- tibble::tribble(
    ~GroupID, ~GroupLevel, ~Param, ~Value,
    "0X001", "Site", "InvestigatorFirstName", "Ada",
    "0X001", "Site", "InvestigatorLastName", "Lovelace",
    "0X002", "Site", "InvestigatorLastName", "Curie",
    "0X003", "Site", "InvestigatorFirstName", "Alan",
    "0X003", "Site", "InvestigatorLastName", "Turing"
  )
  dplyr::bind_rows(study, sites)
}

elig_FixtureRecords <- function() {
  tibble::tribble(
    ~studyid, ~subjid, ~source, ~record_id, ~record_date, ~Folder, ~Form, ~QueryText, ~Status, ~Description,
    "S1", "P03", "EDC Query", "Q1", "2026-10-01", "ENROLL", "IE", "Please check I/E", "Open", NA,
    "S1", "P01", "EDC Query", "Q2", "2026-09-01", "ENROLL", "IE", "Check criterion", "Answered", NA,
    "S1", "P06", "EDC PD", "D1", NA, "SCRN", "PD", NA, "Active", NA,
    "S1", "P02", "Protocol Deviation", "PD-9", "2026-01-02", NA, NA, NA, NA, "PD one"
  )
}

elig_FixtureResults <- function(bRisk = FALSE) {
  rate <- tibble::tibble(
    GroupID = "S1", GroupLevel = "Study", MetricID = "Analysis_qtl0001",
    SnapshotDate = as.Date(c("2026-09-01", "2026-10-01", "2026-11-01")),
    Numerator = c(2L, 3L, 4L), Denominator = c(6L, 7L, 8L),
    Metric = c(2 / 6, 3 / 7, 4 / 8), Score = NA_real_, Flag = NA_real_
  )
  if (!bRisk) return(rate)
  risk <- rate[2:3, ]
  risk$MetricID <- "Analysis_elig0001"
  risk$Numerator <- c(4L, 6L)
  risk$Metric <- risk$Numerator / risk$Denominator
  dplyr::bind_rows(rate, risk)
}

elig_FixtureMetrics <- function() {
  tibble::tibble(MetricID = "Analysis_qtl0001", nPropRate = 0.3, nNumDeviations = 3)
}
