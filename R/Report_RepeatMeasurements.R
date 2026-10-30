#' Report_RepeatMeasurements function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates the Repeat Measurements report for the repeat-measure KRIs
#' (`kri0020a`–`f`, `cou0020a`–`f`): consecutive identical vital sign values
#' at study, country, site and participant level, with a participant listing,
#' a vitals listing and a data table.
#'
#' The flag rule, thresholds, minimum windows and blood pressure view set the
#' report's starting settings; reviewers can change them in the report's
#' Settings panel, which recomputes every participant flag in the browser.
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
#' @param strFlagRule `character` Participant flag rule, `"count"` (default)
#'   or `"rate"`. See [rm_Classify()].
#' @param vFlagThresholds `numeric` Amber and Red thresholds for
#'   `strFlagRule`. Default `NULL`: 2 and 3 repeating windows, or the
#'   `kri0020` rate thresholds. See [rm_Classify()].
#' @param nMinWindows `numeric` Windows a participant needs for a flag.
#'   Default 1.
#' @param strBPMode `character` Blood pressure view: `"separate"` (default,
#'   systolic and diastolic BP), `"combined"` (paired BP only) or `"both"`.
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
  strFlagRule = c("count", "rate"),
  vFlagThresholds = NULL,
  nMinWindows = 1,
  strBPMode = c("separate", "combined", "both"),
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
  strBPMode <- match.arg(strBPMode)
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
      vFlagThresholds = vFlagThresholds,
      nMinWindows = nMinWindows,
      strBPMode = strBPMode,
      bExport = bExport
    )
  )
}
