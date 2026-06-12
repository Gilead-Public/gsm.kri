#' Report_Eligibility function
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' This function generates a Eligibility report based on the provided inputs.
#'
#' @param dfResults `data.frame` Analysis results data.
#' @param dfMetrics `data.frame` Analysis metrics data.
#' @param dfGroups `data.frame` Analysis groups data.
#' @param lListings `list` List containing appropriate dataset to display for eligiiblity listing
#' @param strOutputDir The output directory path for the generated report. If not provided,
#'  the report will be saved in the current working directory.
#' @param strOutputFile The output file name for the generated report. If not provided,
#'  the report will be named based on the study ID, Group Level and Date.
#' @param strInputPath `string` or `fs_path` Path to the template `Rmd` file.
#'
#' @return File path of the saved report html is returned invisibly. Save to object to view absolute output path.
#' @examples
#' \dontrun{
#' # Run study-level Eligibility report.
#' dfResults <- gsm.core::reportingResults_study %>%
#'   filter(MetricID %in% "Analysis_qtl0001") %>%
#'   mutate(MetricID = "study_eligibility")
#'
#' dfMetrics <- gsm.core::reportingMetrics_study %>%
#'   filter(MetricID %in% "Analysis_qtl0001") %>%
#'   mutate(MetricID = "study_eligibility")
#'
#' dfGroups <- gsm.core::reportingGroups_study
#'
#' mappings_wf <- workr::MakeWorkflowList(
#'   strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
#'   strPath = "workflow/1_mappings",
#'   strPackage = "gsm.mapping"
#' )
#' mappings_spec <- gsm.mapping::CombineSpecs(mappings_wf)
#' lRaw <- map_depth(
#'   list(gsm.core::lSource),
#'   1,
#'   gsm.mapping::Ingest,
#'   mappings_spec
#' )
#' mapped <- map_depth(lRaw, 1, ~ workr::RunWorkflows(mappings_wf, .x))
#'
#' # test rendering of report
#' lListings <- list(
#'   IE = mapped[[1]]$Mapped_EXCLUSION
#' )
#'
#' lParams <- list(
#'   dfResults = dfResults,
#'   dfMetrics = dfMetrics,
#'   dfGroups = dfGroups,
#'   lListings = lListings
#' )
#'
#' # Local call to render function - run from pkg root
#' Report_Eligibility(
#'   lParams = lParams,
#'   strOutputDir = file.path(getwd(), "pkgdown", "assets", "examples"),
#'   strOutputFile = "Example_Eligibility.html",
#'   strInputPath = file.path(
#'     getwd(), "pkgdown", "menus", "examples", "report/Report_Eligibility.Rmd"
#'   )
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
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_Eligibility()`")
  rlang::check_installed("knitr", reason = "to run `Report_Eligibility()`")
  rlang::check_installed("gsm.qtl", reason = "to run `Report_Eligibility()`")

  # set output path
  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_Eligibility.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      lListings = lListings
    )
  )
}
