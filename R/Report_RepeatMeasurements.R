#' Report_RepeatMeasurements function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates the Repeat Measurements report for the repeat-measure KRIs
#' (`kri0020a`–`f`, `cou0020a`–`f`): consecutive identical vital sign values,
#' in five sections: study overview, site/country distribution, participant
#' listing, measure listing and data table.
#'
#' The flag rule, thresholds, minimum windows and blood pressure view set the
#' report's starting settings; reviewers can change them in the report's
#' Settings panel, which recomputes every participant flag in the browser.
#'
#' The `rep_*()` functions build the report's pieces. They are exported for
#' the report template and are not intended to be called directly.
#'
#' @section Measures:
#' `rep_Vitals()` lists the measures the report knows: the six scored by
#' `kri0020a`–`f` / `cou0020a`–`f`, paired blood pressure (`bp`), height and
#' BSA. Any other numeric `Mapped_VS` column is also windowed and flagged, but
#' only the six have a KRI. Timing and ID columns are skipped: `studyid`,
#' `subjid`, `invid`, `country`, `visit`, `vs_dt`, `vsperf_std`, and any name
#' (ignoring case) starting with `visit` or ending in `dy`, `num`, `seq` or
#' `id`, plus the report's own `record`, `in_repeat_window` and `window_start`.
#'
#' Paired blood pressure is report-only and added when `sysbp` and `diabp` are
#' present: one value per record with both, so a window repeats only when both
#' repeat over the same visits. It does not reconcile with `kri0020c` /
#' `kri0020d`.
#'
#' @section Participant flags:
#' `rep_Classify()` windows every measure of every enrolled participant once,
#' with the engine behind [Detect_ConsecutiveRepeats()], so every section
#' reads one frame; summing `Numerator` and `Denominator` by site or country
#' reproduces the metrics. A character `vs_dt` must hold ISO dates. When
#' `dfMetrics` has a window length, it wins over `nWindowLength` (with a
#' warning if they differ); otherwise the default is 3.
#'
#' A participant's flag for a measure comes from [gsm.core::Flag()]:
#' * `"count"`: repeating windows (`Numerator`) against `vFlagThresholds`.
#' * `"rate"`: `Numerator / Denominator` against `vFlagThresholds`.
#'
#' Amber is at or above the first threshold, Red at or above the second.
#' Participants with fewer than `nMinWindows` windows are `Not evaluable`.
#' `rep_FlagThresholds()` supplies the defaults: 2 and 3 for `"count"`; for
#' `"rate"`, the site-level `kri0020` / `cou0020` `Threshold` in `dfMetrics`,
#' else 0.2 and 0.3. The rate defaults reuse site thresholds at the
#' participant grain, a starting point rather than a calibration: a
#' participant has far fewer windows than a site, so one repeating window
#' moves the rate a lot.
#'
#' `rep_Classify()` returns a `list` with `participants` (one row per
#' participant and measure, with `Numerator`, `Denominator`, `rate` and
#' `flag`), `measurements` (one row per non-missing measurement with its
#' repeat-window marks), `records` (the enrolled participants' `Mapped_VS`
#' rows with a `record` key), `vitals` (the measures in the report) and
#' `meta` (`window_length`, `window_source`, `rule`, `thresholds`,
#' `min_windows`, and `split_sites`: sites with more than one country, which
#' raise a warning).
#'
#' @section Site flags:
#' `rep_SiteFlagRows()` returns one flag per site and measure (`0` Green, `1`
#' Amber, `2` Red, `NA` not evaluated). A KRI measure with `kri0020a`–`f` site
#' results takes the latest KRI flag (`source = "KRI"`); every other measure
#' is flagged in the report with the `kri0020` steps
#' ([gsm.core::Input_Rate()], [gsm.core::Transform_Rate()],
#' [gsm.core::Analyze_Identity()], [gsm.core::Flag()]; `source = "report"`)
#' using `rep_SiteRule()`: Amber and Red at the metric `Threshold` (default
#' 0.2 and 0.3) for sites with at least `AccrualThreshold` windows (default
#' 3).
#'
#' @section Report sections:
#' Each section is built from the output of `rep_Classify()` (`lClass`) and
#' sorted by worst flag, then most repeating windows, then participant.
#' * `rep_Header()`, `rep_Toolbar()` and `rep_Seg()` build the header card,
#'   the sticky filter strip and its segmented toggle buttons. `rmFilters.js`
#'   finds their elements by data attribute and rewrites them as the reviewer
#'   changes the settings.
#' * `rep_ParticipantTiles()` returns one tile per participant and measure,
#'   drawn by [Widget_RepeatMeasurementsTiles()].
#' * `rep_VitalRows()` returns the measure listing, one row per participant
#'   and measure with aligned, space-separated `values` and
#'   `in_repeat_window`; `rep_VitalsListing()` renders it as a `DT` table.
#' * `rep_DataTableWide()` returns one row per `Mapped_VS` record with one
#'   column and one `<vital>_in_repeat_window` column per measure;
#'   `rep_DataTable()` renders it as a `DT` table, from which the browser
#'   also builds the Long table.
#'
#' The tables name every column so the filter script can find it; their CSV
#' buttons export the rows the filters show.
#'
#' @param dfResults `data.frame` Reporting results. With `kri0020` results the
#'   report colours sites by their KRI flag.
#' @param dfMetrics `data.frame` Reporting metrics (`ID`, `Threshold`, ...).
#'   The window length and thresholds come from the `kri0020` rows when
#'   present.
#' @param lListings `list` with `Mapped_SUBJ` (`subjid`, `invid`, `country`;
#'   `studyid` optional; a missing `invid` or `country` is shown as
#'   `"(missing)"`) and `Mapped_VS` (`subjid`, `vs_dt`, optional `visit`
#'   and `vsperf_std`, and one numeric column per measure).
#' @param dSnapshotDate `Date` Shown in the report header. Default: the latest
#'   `dfResults$SnapshotDate`, if any.
#' @param nWindowLength `integer` Window length when `dfMetrics` has none.
#'   Shown in the measure listing header. See "Participant flags".
#' @param strFlagRule `character` Participant flag rule, `"count"` (default)
#'   or `"rate"`. See "Participant flags".
#' @param vFlagThresholds `numeric` Amber and Red thresholds for
#'   `strFlagRule`: window counts for `"count"`, proportions such as
#'   `c(0.2, 0.3)` for `"rate"`. Default `NULL`; see "Participant flags".
#' @param nMinWindows `numeric` Windows a participant needs for a flag.
#'   Default 1.
#' @param strBPMode `character` Blood pressure view: `"separate"` (default,
#'   systolic and diastolic BP), `"combined"` (paired BP only) or `"both"`.
#' @param bExport `logical` Show the CSV download buttons. Default: `TRUE`.
#' @param strContext `character` HTML shown above the report title, such as a
#'   link back to a study page. Inserted as is, so it must be trusted HTML.
#'   Default: `""` (none).
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default:
#'   `Report_RepeatMeasurements.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#' @param lClass `list` Output of `rep_Classify()`.
#' @param strStudy `character` Study ID(s) shown in the header; missing and
#'   empty IDs are dropped.
#' @param dfVitals `data.frame` The `vitals` element of `rep_Classify()`. An
#'   optional logical `kri` column limits the KRI badge to measures with
#'   results.
#' @param lSettings `list` Initial settings: `rule`, `thresholds`,
#'   `minWindows` and `bp`.
#' @param strLabel `character` Accessible label of a button group.
#' @param vValues `character` Button labels, named by value.
#' @param strSelected `character` The value pressed initially.
#' @param strAttr `character` Data attribute the script reads, such as
#'   `"data-rm-ov"`.
#' @param strGroup `character` Optional. When given, every button sets
#'   `strAttr` to `strGroup` and carries its value in `value`.
#' @param strIdPrefix `character` Optional prefix of each button's `id`.
#' @param dfWide `data.frame` Output of `rep_DataTableWide()`.
#' @param dfVitalRows `data.frame` Output of `rep_VitalRows()`.
#'
#' @return `Report_RepeatMeasurements()`: file path of the saved report HTML,
#'   returned invisibly. `rep_Classify()`: a `list` (see "Participant
#'   flags"). `rep_Header()`, `rep_Toolbar()`, `rep_Seg()`: `htmltools` tags.
#'   `rep_DataTable()`, `rep_VitalsListing()`: `DT` htmlwidgets.
#'   `rep_FlagThresholds()`: `numeric` Amber, then Red. `rep_SiteRule()`: a
#'   `list` with `thresholds` and `accrual`. Other `rep_*()` functions: a
#'   `tibble`.
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
  strContext = "",
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_RepeatMeasurements.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed(
    "knitr",
    reason = "to run `Report_RepeatMeasurements()`"
  )
  strFlagRule <- match.arg(strFlagRule)
  strBPMode <- match.arg(strBPMode)
  gsm.core::stop_if(
    cnd = !is.character(strContext) ||
      length(strContext) != 1 ||
      is.na(strContext),
    message = "strContext must be a single character string"
  )
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

  RenderRmd(
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
      bExport = bExport,
      strContext = strContext
    )
  )
}
