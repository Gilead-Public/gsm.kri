#' Report_Eligibility function
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Generates the Eligibility report: enrolled participants by eligibility
#' status at study, country and site level, flag sources, EDC I/E criteria
#' views, the Ineligibility listing and the eligibility rules.
#'
#' The study picks the mode with `strMode`:
#' - **Basic** (default, every study): two statuses, Ineligible
#'   (`Source != 'Neither'`) and No Eligibility Risk, computed as before.
#' - **Pilot**: a third status, Potentially Ineligible, from the `edc_query`
#'   and `edc_pd` columns. With no data in either, the report
#'   warns and falls back to basic.
#'
#' @section Data contract:
#' Each level is optional and unlocks more of the report.
#' 1. **Columns** on `lListings$IE_denom` (`Mapped_EXCLUSION`), `"Y"`/`"N"`:
#'    `pd_important` and `pd_nonimportant` (split the PD source),
#'    `edc_query` and `edc_pd` (pilot mode; `NA` throughout when the source
#'    is not delivered, and the listing shows "N/A"). A
#'    participant is Ineligible when `Source != 'Neither'`, otherwise
#'    Potentially Ineligible when `edc_query` or `edc_pd` is `"Y"`, otherwise
#'    No Eligibility Risk. `Source` itself never carries Potentially Ineligible.
#'    `iecat_concat`, the I/E category (`"IN"`/`"EX"`) of each code in
#'    `ietestcd_concat` order, splits the criteria into Inclusion and
#'    Exclusion; without it they are Not classified.
#' 2. **Records**: `lListings$IE_records`, one row per record behind a flag,
#'    with `studyid`, `subjid`, `source` (`record_source` of [elig_Setup()]:
#'    by default `"EDC eCRF"`, `"Protocol Deviation"`, `"EDC Query"`,
#'    `"EDC PD"`), `record_id`, `record_date` and the source's
#'    key fields as further columns. Fills the listing's expanded rows and the
#'    CSV details columns (pilot mode).
#' 3. **Status history**: `dfStatusHistory`, the rows of
#'    [elig_StatusCounts()] that the study saves every snapshot, with
#'    `SnapshotDate`. Adds the Status over Time tab (pilot mode).
#'
#' Rows of `dfGroups` at `strInvestigatorLevel` whose `Param` is in
#' `vInvestigatorParams` (see [elig_Setup()]) fill the listing's Investigator
#' Name; without such rows, the column is blank.
#'
#' @param dfResults `data.frame` Analysis results: the study-level eligibility
#'   rate (qtl0001).
#' @param dfMetrics `data.frame` Analysis metrics data.
#' @param dfGroups `data.frame` Analysis groups data.
#' @param lListings `list` with `IE_denom` (`Mapped_EXCLUSION`), `IE_num`
#'   (its ineligible rows) and, optionally, `IE_records`.
#' @param strOutputDir The output directory path for the generated report. If not provided,
#'  the report will be saved in the current working directory.
#' @param strOutputFile The output file name for the generated report. If not provided,
#'  the report will be named `Report_Eligibility.html`.
#' @param strInputPath `string` or `fs_path` Path to the template `Rmd` file.
#' @param strMode `character` `"basic"` (default) or `"pilot"`.
#' @param dfStatusHistory `data.frame` Status history (level 3). Default:
#'   `NULL`.
#' @param lSetup `list` Study configuration from [elig_Setup()]: source names
#'   and order, rate metric, criterion colours and investigator name fields.
#'   Default: `elig_Setup()`.
#'
#' @return File path of the saved report html is returned invisibly. Save to object to view absolute output path.
#' @examples
#' \dontrun{
#' dfResults <- gsm.core::reportingResults_study %>%
#'   dplyr::filter(MetricID == "Analysis_qtl0001")
#' dfMetrics <- gsm.core::reportingMetrics_study %>%
#'   dplyr::filter(MetricID == "Analysis_qtl0001")
#'
#' mappings_wf <- workr::MakeWorkflowList(
#'   strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
#'   strPath = "workflow/1_mappings",
#'   strPackage = "gsm.mapping"
#' )
#' lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(mappings_wf))
#' mapped <- workr::RunWorkflows(mappings_wf, lRaw)
#'
#' Report_Eligibility(
#'   dfResults = dfResults,
#'   dfMetrics = dfMetrics,
#'   dfGroups = gsm.core::reportingGroups,
#'   lListings = list(
#'     IE_num = dplyr::filter(mapped$Mapped_EXCLUSION, Source != "Neither"),
#'     IE_denom = mapped$Mapped_EXCLUSION
#'   ),
#'   strOutputDir = tempdir(),
#'   lSetup = elig_Setup()
#' )
#' }
#'
#' @keywords KRI report
#' @export
#'

Report_Eligibility <- function(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_Eligibility.Rmd",
    package = "gsm.kri"
  ),
  strMode = c("basic", "pilot"),
  dfStatusHistory = NULL,
  lSetup = elig_Setup()
) {
  rlang::check_installed("knitr", reason = "to run `Report_Eligibility()`")

  # Rebuilt through elig_Setup() so a hand-edited list is validated before render.
  if (!is.list(lSetup) || !all(names(elig_Setup()) %in% names(lSetup))) {
    cli::cli_abort("{.arg lSetup} must be a list from {.fn elig_Setup}.")
  }
  lSetup <- do.call(elig_Setup, lSetup[names(elig_Setup())])

  # set output path
  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_Eligibility.html"
  }

  # Resolved here, not in the Rmd: warnings raised while knitting never reach the caller.
  dfExclusion <- if (!is.null(lListings$IE_denom)) lListings$IE_denom else lListings$IE_num
  strMode <- elig_Mode(dfExclusion, strMode)

  RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      lListings = lListings,
      strMode = strMode,
      dfStatusHistory = dfStatusHistory,
      lSetup = lSetup
    )
  )
}
