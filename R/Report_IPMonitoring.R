#' Report_IPMonitoring function
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
#'   `Mapped_STUDCOMP`. Without `drv_drg_completion` in `Mapped_SUBJ`, dosed
#'   participants show as Unrecognized status and the treatment completion
#'   figures and reasons are not available.
#' @param dSnapshotDate `Date` "Today" for the day counts. Default: the latest
#'   `dfResults$SnapshotDate`.
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default:
#'   `Report_IPMonitoring.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @keywords KRI report
#' @export
Report_IPMonitoring <- function(
  dfResults = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_IPMonitoring.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_IPMonitoring()`")
  rlang::check_installed("knitr", reason = "to run `Report_IPMonitoring()`")
  rlang::check_installed("plotly", reason = "to run `Report_IPMonitoring()`")
  rlang::check_installed("DT", reason = "to run `Report_IPMonitoring()`")

  if (is.null(dSnapshotDate) && !is.null(dfResults$SnapshotDate)) {
    dSnapshotDate <- max(as.Date(dfResults$SnapshotDate))
  }
  gsm.core::stop_if(
    cnd = is.null(dSnapshotDate),
    message = "Provide dSnapshotDate or dfResults with a SnapshotDate column"
  )

  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_IPMonitoring.html"
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
