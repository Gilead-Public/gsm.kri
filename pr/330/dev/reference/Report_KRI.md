# Report_KRI function

\`r lifecycle::badge("stable")\`

This function generates a KRI report based on the provided inputs.

## Usage

``` r
Report_KRI(
  lCharts = NULL,
  dfResults = NULL,
  dfMetrics = NULL,
  dfGroups = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_KRI.Rmd", package = "gsm.kri")
)
```

## Arguments

- lCharts:

  A list of charts to include in the report.

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

- dfMetrics:

  \`data.frame\` Metric-specific metadata for use in charts and
  reporting. Created by passing an \`lWorkflow\` object to
  \[MakeMetric()\]. Expected columns: \`File\`, \`MetricID\`, \`Group\`,
  \`Abbreviation\`, \`Metric\`, \`Numerator\`, \`Denominator\`,
  \`Model\`, \`Score\`, and \`Threshold\`. For more details see the Data
  Model vignette: \`vignette("DataModel", package = "gsm.core")\`.

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- strOutputDir:

  The output directory path for the generated report. If not provided,
  the report will be saved in the current working directory.

- strOutputFile:

  The output file name for the generated report. If not provided, the
  report will be named based on the study ID, Group Level and Date.

- strInputPath:

  \`string\` or \`fs_path\` Path to the template \`Rmd\` file.

## Value

File path of the saved report html is returned invisibly. Save to object
to view absolute output path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Run site-level KRI report.
lChartsSite <- MakeCharts(
  dfResults = gsm.core::reportingResults,
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  dfBounds = gsm.core::reportingBounds
)

strOutputFile <- "StandardSiteReport.html"
kri_report_path <- Report_KRI(
  lCharts = lChartsSite,
  dfResults = gsm.core::reportingResults %>%
    FilterByLatestSnapshotDate() %>%
    gsm.reporting::CalculateChange(
      gsm.core::reportingResults
    ),
  dfMetrics = gsm.core::reportingMetrics,
  dfGroups = gsm.core::reportingGroups,
  strOutputFile = strOutputFile
)

# Run country-level KRI report.
lChartsCountry <- MakeCharts(
  dfResults = gsm.core::reportingResults_country,
  dfMetrics = gsm.core::reportingMetrics_country,
  dfGroups = gsm.core::reportingGroups_country,
  dfBounds = gsm.core::reportingBounds_country
)

strOutputFile <- "StandardCountryReport.html"
kri_report_path <- Report_KRI(
  lCharts = lChartsCountry,
  dfResults = gsm.core::reportingResults_country %>%
    FilterByLatestSnapshotDate() %>%
    gsm.reporting::CalculateChange(
      gsm.core::reportingResults_country
    ),
  dfMetrics = gsm.core::reportingMetrics_country,
  dfGroups = gsm.core::reportingGroups_country,
  strOutputFile = strOutputFile
)
} # }
```
