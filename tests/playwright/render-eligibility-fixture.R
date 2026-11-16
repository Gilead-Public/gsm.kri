# Renders the Eligibility report fixtures for the Playwright specs:
# - fixture/Report_Eligibility.html: basic mode, gsm.mapping's EXCLUSION on
#   gsm.core::lSource (two statuses);
# - fixture/Report_Eligibility_pilot.html: pilot mode, the same participants
#   plus the optional level 1 columns, level 2 records and the level 3 history
#   metric of gsm.roadmap#113 (three statuses).
# Source this with the gsm.kri package loaded and the working directory at the
# package root so the relative fixture path resolves.
library(dplyr)

mappings_wf <- workr::MakeWorkflowList(
  strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
  strPath = "workflow/1_mappings",
  strPackage = "gsm.mapping"
)
lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(mappings_wf))
dfExclusion <- workr::RunWorkflows(mappings_wf, lRaw)$Mapped_EXCLUSION

dfResults <- gsm.core::reportingResults_study %>% filter(MetricID == "Analysis_qtl0001")
dfMetrics <- gsm.core::reportingMetrics_study %>% filter(MetricID == "Analysis_qtl0001")
dfGroups <- gsm.core::reportingGroups

dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)
out_dir <- normalizePath("tests/playwright/fixture")

lListings <- function(df, ...) list(IE_num = filter(df, Source != "Neither"), IE_denom = df, ...)

Report_Eligibility(
  dfResults = dfResults, dfMetrics = dfMetrics, dfGroups = dfGroups,
  lListings = lListings(dfExclusion),
  strOutputDir = out_dir, strOutputFile = "Report_Eligibility.html"
)

# Pilot: deterministic flags. Every 9th participant has an open I/E query and
# every 23rd an active EDC PD; PDs split by importance on the PD terms.
n <- nrow(dfExclusion)
idx <- seq_len(n)
dfPilot <- dfExclusion %>%
  mutate(
    pd_important = ifelse(!is.na(eligibility_criteria) & idx %% 2 == 0, "Y", "N"),
    pd_nonimportant = ifelse(!is.na(eligibility_criteria) & idx %% 2 == 1, "Y", "N"),
    edc_query = ifelse(idx %% 9 == 0, "Y", "N"),
    edc_pd = ifelse(idx %% 23 == 0, "Y", "N")
  )
dfRecords <- bind_rows(
  dfPilot %>%
    filter(ie_violation == "Y") %>%
    tidyr::separate_longer_delim(ietestcd_concat, delim = ",") %>%
    transmute(
      studyid, subjid, source = "EDC eCRF", record_id = paste0("IE-", row_number()),
      record_date = NA_character_, Form = "Inclusion/Exclusion Criteria",
      Response = paste0(ietestcd_concat, ": ", ifelse(grepl("^incl", ietestcd_concat), "No", "Yes"))
    ),
  dfPilot %>%
    filter(edc_query == "Y") %>%
    transmute(
      studyid, subjid, source = "EDC Query", record_id = paste0("Q", row_number()),
      record_date = "2025-05-20", Folder = "ENROLL", Form = "Inclusion/Exclusion Criteria",
      QueryText = "Please confirm the participant meets inclusion criterion 4; source shows a value outside the protocol range.",
      MarkingGroupName = "CDA to Site Manual Query", Status = "Open"
    ),
  dfPilot %>%
    filter(edc_pd == "Y") %>%
    transmute(
      studyid, subjid, source = "EDC PD", record_id = paste0("D", row_number()),
      record_date = NA_character_, Folder = "SCRN", Form = "Protocol Deviation", Status = "Active"
    ),
  dfPilot %>%
    filter(!is.na(eligibility_criteria)) %>%
    transmute(
      studyid, subjid, source = "Protocol Deviation", record_id = paste0("PD-", row_number()),
      record_date = substr(dvdtm, 1, 10), Description = eligibility_criteria,
      Classification = ifelse(pd_important == "Y", "Important", "Non-important")
    )
)

# Level 3: the risk metric from the third snapshot on (no back-fill), with a
# Potentially Ineligible share of about a tenth of enrolled.
dfRisk <- dfResults %>%
  arrange(SnapshotDate) %>%
  slice(-(1:2)) %>%
  mutate(
    MetricID = "Analysis_elig0001",
    Numerator = Numerator + round(Denominator / 10),
    Metric = Numerator / Denominator
  )

Report_Eligibility(
  dfResults = bind_rows(dfResults, dfRisk), dfMetrics = dfMetrics, dfGroups = dfGroups,
  lListings = lListings(dfPilot, IE_records = dfRecords),
  strOutputDir = out_dir, strOutputFile = "Report_Eligibility_pilot.html"
)
cat("Rendered:", list.files(out_dir, "Report_Eligibility", full.names = TRUE), sep = "\n")
