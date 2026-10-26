# Report_RepeatMeasurements function

\`r lifecycle::badge("experimental")\`

Generates the Repeat Measurements report for the repeat-measure KRIs
(\`kri0020a\`–\`f\`, \`cou0020a\`–\`f\`): consecutive identical vital
sign values at study, country, site and participant level, with a
participant listing, a vitals listing and a data table.

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
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_RepeatMeasurements.Rmd", package =
    "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results. With \`kri0020\` results the report
  reconciles with the KRI and colours sites by their KRI flag.

- dfMetrics:

  \`data.frame\` Reporting metrics. The window length and thresholds
  come from the \`kri0020\` rows when present.

- lListings:

  \`list\` with \`Mapped_VS\` and \`Mapped_SUBJ\`.

- dSnapshotDate:

  \`Date\` Shown in the subtitle. Default: the latest
  \`dfResults\$SnapshotDate\`, if any.

- nWindowLength:

  \`integer\` Window length when \`dfMetrics\` has none. See
  \[rm_Classify()\].

- strFlagRule:

  \`character\` Participant flag rule, \`"count"\` (default) or
  \`"rate"\`. See \[rm_Classify()\].

- vFlagThresholds:

  \`numeric\` Amber and Red thresholds for \`strFlagRule\`. Default
  \`NULL\`: 2 and 3 repeating windows, or the \`kri0020\` rate
  thresholds. See \[rm_Classify()\].

- nMinWindows:

  \`numeric\` Windows a participant needs for a flag. Default 1.

- strBPMode:

  \`character\` Blood pressure view: \`"separate"\` (default, systolic
  and diastolic BP), \`"combined"\` (paired BP only) or \`"both"\`.

- bExport:

  \`logical\` Show the CSV download buttons. Default: \`TRUE\`.

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
