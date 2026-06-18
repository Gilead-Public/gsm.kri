#' Report_PrematureDeaths function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates a premature-deaths domain report with stacked sections per group
#' level (Study -> Country -> Site) and a patient listing.
#'
#' @param dfResults `data.frame` Analysis results data (must contain
#'   `Analysis_pat0015` rows for the patient listing).
#' @param dfMetrics `data.frame` Analysis metrics data.
#' @param dfGroups `data.frame` Analysis groups data.
#' @param lListings `list` containing `Mapped_Death` and `Mapped_SUBJ` frames,
#'   and optionally `Mapped_EXCLUSION` (adds the Eligibility Status column to the
#'   patient listing).
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#'   **Must equal the `meta.WindowDays` used when `pat0015` produced `dfResults`.**
#'   The charts recompute premature status live from `Mapped_Death` at this
#'   `nWindowDays`, while the patient listing trusts `pat0015`'s `Flag == 2`
#'   rows (flagged at analysis-time `meta.WindowDays`). If the two windows
#'   differ the report's charts and listing silently disagree; the Rmd emits a
#'   `cli_alert_warning` when it detects this mismatch (see the Rmd template).
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default: `Report_PrematureDeaths.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @keywords KRI report
#' @export
Report_PrematureDeaths <- function(
  dfResults = NULL,
  dfMetrics = NULL,
  dfGroups = NULL,
  lListings = NULL,
  nWindowDays = 90,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_PrematureDeaths.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed(
    "rmarkdown",
    reason = "to run `Report_PrematureDeaths()`"
  )
  rlang::check_installed("knitr", reason = "to run `Report_PrematureDeaths()`")
  rlang::check_installed("plotly", reason = "to run `Report_PrematureDeaths()`")
  rlang::check_installed("DT", reason = "to run `Report_PrematureDeaths()`")

  gsm.core::stop_if(
    cnd = !(is.numeric(nWindowDays) &&
      length(nWindowDays) == 1 &&
      nWindowDays > 0),
    message = "nWindowDays must be a positive number"
  )

  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_PrematureDeaths.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      lListings = lListings,
      nWindowDays = nWindowDays
    )
  )
}
