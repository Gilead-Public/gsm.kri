# Renders the Eligibility report fixtures for the Playwright specs:
# - fixture/Report_Eligibility.html: basic mode, gsm.mapping's EXCLUSION on
#   gsm.core::lSource (two statuses);
# - fixture/Report_Eligibility_pilot.html: pilot mode, the same participants
#   plus the optional level 1 columns, level 2 records and the level 3 status
#   history of the data contract (three statuses);
# - fixture/Report_Eligibility_pilot_noquery.html: pilot mode with the EDC Query
#   source and iecat_concat not delivered.
# Source this with the gsm.kri package loaded and the working directory at the
# package root so the relative fixture path resolves.
library(dplyr)

mappings_wf <- workr::MakeWorkflowList(
  strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
  strPath = "workflow/1_mappings",
  strPackage = "gsm.mapping"
)
lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(mappings_wf))
lMapped <- workr::RunWorkflows(mappings_wf, lRaw)
dfExclusion <- lMapped$Mapped_EXCLUSION

# gsm.mapping releases before #188 don't carry iecat_concat: derive it from
# Mapped_IE, code by code in ietestcd_concat order.
if (!"iecat_concat" %in% names(dfExclusion)) {
  dfIE <- distinct(lMapped$Mapped_IE, subjid, ietestcd, iecat_custom)
  dfExclusion$iecat_concat <- mapply(function(id, codes) {
    if (is.na(codes)) return(NA_character_)
    v <- strsplit(codes, ",", fixed = TRUE)[[1]]
    paste(dfIE$iecat_custom[match(paste(id, v), paste(dfIE$subjid, dfIE$ietestcd))], collapse = ",")
  }, dfExclusion$subjid, dfExclusion$ietestcd_concat, USE.NAMES = FALSE)
}

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
      MarkingGroupName = "Site Query", Status = "Open"
    ),
  dfPilot %>%
    filter(edc_pd == "Y") %>%
    transmute(
      studyid, subjid, source = "EDC PD", record_id = paste0("D", row_number()),
      record_date = NA_character_, Folder = "SCRN", Form = "Protocol Deviation", Status = "Active"
    ),
  dfPilot %>%
    filter(!is.na(eligibility_criteria)) %>%
    # Mapped_EXCLUSION joins a participant's PDs; level 2 has one row per PD.
    tidyr::separate_longer_delim(c(dvdtm, eligibility_criteria), delim = ";;;") %>%
    transmute(
      studyid, subjid, source = "Protocol Deviation", record_id = paste0("PD-", row_number()),
      record_date = substr(dvdtm, 1, 10), Description = eligibility_criteria,
      Classification = ifelse(pd_important == "Y", "Important", "Non-important")
    )
)

# Level 3: the status history from the second snapshot on (no back-fill). The
# earlier snapshot splits Potentially Ineligible off as a tenth of enrolled; the
# latest is this snapshot's counts, as the pipeline saves them.
dfSnapshots <- dfResults %>% arrange(SnapshotDate)
dfStatusHistory <- dfSnapshots %>%
  slice(2) %>%
  reframe(
    GroupLevel = "Study", GroupID = GroupID,
    Status = c("Ineligible", "Potentially Ineligible", "No Eligibility Risk"),
    n = as.integer(c(Numerator, round(Denominator / 10), Denominator - Numerator - round(Denominator / 10))),
    .by = SnapshotDate
  ) %>%
  bind_rows(mutate(elig_StatusCounts(dfPilot, "pilot"), SnapshotDate = max(dfSnapshots$SnapshotDate)))

Report_Eligibility(
  dfResults = dfResults, dfMetrics = dfMetrics, dfGroups = dfGroups,
  lListings = lListings(dfPilot, IE_records = dfRecords),
  strOutputDir = out_dir, strOutputFile = "Report_Eligibility_pilot.html",
  strMode = "pilot", dfStatusHistory = dfStatusHistory
)

# Pilot with EDC Query not delivered (the mapping leaves edc_query NULL) and a
# study EXCLUSION without iecat_concat.
Report_Eligibility(
  dfResults = dfResults, dfMetrics = dfMetrics, dfGroups = dfGroups,
  lListings = lListings(select(mutate(dfPilot, edc_query = NA_character_), -iecat_concat)),
  strOutputDir = out_dir, strOutputFile = "Report_Eligibility_pilot_noquery.html",
  strMode = "pilot"
)
cat("Rendered:", list.files(out_dir, "Report_Eligibility", full.names = TRUE), sep = "\n")
