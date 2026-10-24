#' Report_RepeatMeasurements function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates the Repeat Measurements report for the repeat-measure KRIs
#' (`kri0020a`–`f`, `cou0020a`–`f`): consecutive identical vital sign values
#' at study, country, site and participant level, with a participant listing
#' and a vitals listing.
#'
#' @param dfResults `data.frame` Reporting results. With `kri0020` results the
#'   report reconciles with the KRI and colours sites by their KRI flag.
#' @param dfMetrics `data.frame` Reporting metrics. The window length and
#'   thresholds come from the `kri0020` rows when present.
#' @param lListings `list` with `Mapped_VS` and `Mapped_SUBJ`.
#' @param dSnapshotDate `Date` Shown in the subtitle. Default: the latest
#'   `dfResults$SnapshotDate`, if any.
#' @param nWindowLength `integer` Window length when `dfMetrics` has none.
#'   See [rm_Classify()].
#' @param strFlagRule `character` `"rate"` or `"count"`. See [rm_Classify()].
#' @param bExport `logical` Show the CSV download buttons. Default: `TRUE`.
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default:
#'   `Report_RepeatMeasurements.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @examples
#' \dontrun{
#' Report_RepeatMeasurements(
#'   dfResults = lReporting$Reporting_Results,
#'   dfMetrics = lReporting$Reporting_Metrics,
#'   lListings = list(
#'     Mapped_VS = lMapped$Mapped_VS,
#'     Mapped_SUBJ = lMapped$Mapped_SUBJ
#'   )
#' )
#' }
#'
#' @keywords KRI report
#' @export
Report_RepeatMeasurements <- function(
  dfResults = NULL,
  dfMetrics = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  nWindowLength = NULL,
  strFlagRule = c("rate", "count"),
  bExport = TRUE,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_RepeatMeasurements.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_RepeatMeasurements()`")
  rlang::check_installed("knitr", reason = "to run `Report_RepeatMeasurements()`")
  rlang::check_installed("DT", reason = "to run `Report_RepeatMeasurements()`")
  strFlagRule <- match.arg(strFlagRule)
  gsm.core::stop_if(
    cnd = !is.list(lListings) || !is.data.frame(lListings$Mapped_SUBJ),
    message = "lListings must be a list with a Mapped_SUBJ data.frame"
  )

  if (is.null(dSnapshotDate) && !is.null(dfResults$SnapshotDate)) {
    dSnapshotDate <- max(as.Date(dfResults$SnapshotDate))
  }
  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_RepeatMeasurements.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      lListings = lListings,
      dSnapshotDate = dSnapshotDate,
      nWindowLength = nWindowLength,
      strFlagRule = strFlagRule,
      bExport = bExport
    )
  )
}
