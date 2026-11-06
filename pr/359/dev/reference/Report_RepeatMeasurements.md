# Report_RepeatMeasurements function

\`r lifecycle::badge("experimental")\`

Generates the Repeat Measurements report for the repeat-measure KRIs
(\`kri0020a\`–\`f\`, \`cou0020a\`–\`f\`): consecutive identical vital
sign values, in five sections: study overview, site/country
distribution, participant listing, measure listing and data table.

The flag rule, thresholds, minimum windows and blood pressure view set
the report's starting settings; reviewers can change them in the
report's Settings panel, which recomputes every participant flag in the
browser.

## Usage

``` r
Report_RepeatMeasurements(
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
  strInputPath = system.file("report", "Report_RepeatMeasurements.Rmd", package =
    "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results. With \`kri0020\` results the report
  colours sites by their KRI flag.

- dfMetrics:

  \`data.frame\` Reporting metrics. The window length and thresholds
  come from the \`kri0020\` rows when present.

- lListings:

  \`list\` with \`Mapped_SUBJ\` (\`subjid\`, \`invid\`, \`country\`;
  \`studyid\` optional) and \`Mapped_VS\` (\`subjid\`, \`vs_dt\`,
  optional \`visit\` and \`vsperf_std\`, and one numeric column per
  measure).

- dSnapshotDate:

  \`Date\` Shown in the report header. Default: the latest
  \`dfResults\$SnapshotDate\`, if any.

- nWindowLength:

  \`integer\` Window length when \`dfMetrics\` has none. See
  \[rep_Classify()\].

- strFlagRule:

  \`character\` Participant flag rule, \`"count"\` (default) or
  \`"rate"\`. See \[rep_Classify()\].

- vFlagThresholds:

  \`numeric\` Amber and Red thresholds for \`strFlagRule\`: window
  counts for \`"count"\`, proportions such as \`c(0.2, 0.3)\` for
  \`"rate"\`. Default \`NULL\`: 2 and 3 repeating windows, or the
  site-level \`kri0020\` / \`cou0020\` rate thresholds. See
  \[rep_FlagThresholds()\].

- nMinWindows:

  \`numeric\` Windows a participant needs for a flag. Default 1.

- strBPMode:

  \`character\` Blood pressure view: \`"separate"\` (default, systolic
  and diastolic BP), \`"combined"\` (paired BP only) or \`"both"\`.

- bExport:

  \`logical\` Show the CSV download buttons. Default: \`TRUE\`.

- strContext:

  \`character\` HTML shown above the report title, such as a link back
  to a study page. Inserted as is, so it must be trusted HTML. Default:
  \`""\` (none).

- strOutputDir:

  \`string\` Output directory. Default: working directory.

- strOutputFile:

  \`string\` Output filename. Default:
  \`Report_RepeatMeasurements.html\`.

- strInputPath:

  \`string\` Path to the template \`Rmd\`.

## Value

File path of the saved report HTML, returned invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
Report_RepeatMeasurements(
  dfResults = lReporting$Reporting_Results,
  dfMetrics = lReporting$Reporting_Metrics,
  lListings = list(
    Mapped_VS = lMapped$Mapped_VS,
    Mapped_SUBJ = lMapped$Mapped_SUBJ
  )
)
} # }
```
