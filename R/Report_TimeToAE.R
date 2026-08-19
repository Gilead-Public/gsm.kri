#' Report_TimeToAE function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates a time-to-first-adverse-event report: a study overview, a
#' Kaplan-Meier event-free curve with flagged groups overlaid, the observed
#' vs. expected scatter with Poisson prediction bounds, and the standard metric
#' charts and flagged group table.
#'
#' @details
#' The report re-derives its subject-level cohort by calling
#' [Input_TimeToEvent()] on `lListings`, which is the same function `kri0019` /
#' `cou0019` use. The curve and the site table therefore always describe the same
#' cohort as the metric that produced `dfResults`.
#'
#' Note that the score is on the event-rate scale, so its sign runs opposite to
#' the metric's name: a negative score is an unexpectedly *long* time to first AE.
#' The report states this inline.
#'
#' @param dfResults `data.frame` Reporting results, containing the rows for
#'   `strMetricID`.
#' @param dfMetrics `data.frame` Reporting metrics metadata.
#' @param dfGroups `data.frame` Reporting groups metadata.
#' @param dfBounds `data.frame` Poisson prediction bounds, as produced by
#'   `gsm.reporting::MakeBounds()` for a metric with `AnalysisType: poisson`.
#' @param lListings `list` containing `Mapped_SUBJ` and `Mapped_AE`, used to
#'   re-derive the subject-level time-to-event cohort for the curve.
#' @param strMetricID `string` Metric to report on. Default:
#'   `"Analysis_kri0019"`. Pass `"Analysis_cou0019"` for the country-level view.
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default:
#'   `Report_TimeToAE.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @keywords KRI report
#' @export
Report_TimeToAE <- function(
  dfResults = NULL,
  dfMetrics = NULL,
  dfGroups = NULL,
  dfBounds = NULL,
  lListings = NULL,
  strMetricID = "Analysis_kri0019",
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_TimeToAE.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_TimeToAE()`")
  rlang::check_installed("knitr", reason = "to run `Report_TimeToAE()`")
  rlang::check_installed("plotly", reason = "to run `Report_TimeToAE()`")

  gsm.core::stop_if(
    cnd = is.null(dfResults),
    message = "dfResults must be provided"
  )
  gsm.core::stop_if(
    cnd = !strMetricID %in% dfResults$MetricID,
    message = paste0("strMetricID '", strMetricID, "' not found in dfResults")
  )
  gsm.core::stop_if(
    cnd = is.null(lListings) ||
      !all(c("Mapped_SUBJ", "Mapped_AE") %in% names(lListings)),
    message = "lListings must contain Mapped_SUBJ and Mapped_AE"
  )

  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_TimeToAE.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups,
      dfBounds = dfBounds,
      lListings = lListings,
      strMetricID = strMetricID
    )
  )
}
