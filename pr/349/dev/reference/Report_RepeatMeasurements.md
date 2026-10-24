# Report_RepeatMeasurements function

\`r lifecycle::badge("experimental")\`

Generates the Repeat Measurements report for the repeat-measure KRIs
(\`kri0020a\`–\`f\`, \`cou0020a\`–\`f\`): consecutive identical vital
sign values at study, country, site and participant level, with a
participant listing and a vitals listing.

## Usage

``` r
Report_RepeatMeasurements(
  dfResults = NULL,
  dfMetrics = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  nWindowLength = NULL,
  strFlagRule = c("rate", "count"),
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

  \`character\` \`"rate"\` or \`"count"\`. See \[rm_Classify()\].

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
