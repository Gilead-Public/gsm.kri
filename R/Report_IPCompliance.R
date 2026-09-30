#' Report_IPCompliance function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates the IP monitoring report: IP non-starters and premature treatment
#' discontinuation for every enrolled participant, at study, country and site
#' level, with a participant listing.
#'
#' @param dfResults `data.frame` Reporting results; the latest `SnapshotDate`
#'   is "today" unless `dSnapshotDate` is given.
#' @param lListings `list` with `Mapped_IPNS`, `Mapped_SUBJ` and
#'   `Mapped_STUDCOMP`. Without `drv_treatment_discontinuation_dt` in
#'   `Mapped_SUBJ` the report runs without premature treatment discontinuation.
#' @param dSnapshotDate `Date` "Today" for the day counts. Default: the latest
#'   `dfResults$SnapshotDate`.
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default:
#'   `Report_IPCompliance.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @keywords KRI report
#' @export
Report_IPCompliance <- function(
  dfResults = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_IPCompliance.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_IPCompliance()`")
  rlang::check_installed("knitr", reason = "to run `Report_IPCompliance()`")
  rlang::check_installed("plotly", reason = "to run `Report_IPCompliance()`")
  rlang::check_installed("DT", reason = "to run `Report_IPCompliance()`")

  if (is.null(dSnapshotDate) && !is.null(dfResults$SnapshotDate)) {
    dSnapshotDate <- max(as.Date(dfResults$SnapshotDate))
  }
  gsm.core::stop_if(
    cnd = is.null(dSnapshotDate),
    message = "Provide dSnapshotDate or dfResults with a SnapshotDate column"
  )

  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_IPCompliance.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      lListings = lListings,
      dSnapshotDate = dSnapshotDate
    )
  )
}
