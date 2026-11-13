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
  strInputPath = system.file("report", "Report_KRI.Rmd", package = "gsm.kri"),
  strComparisonRiskMetric = "Analysis_srs0002",
  strComparisonRiskLabel = "Adjusted Risk Score",
  strGroupSubset = NULL,
  dfRiskScoreDetail = NULL,
  lData = NULL
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

- strComparisonRiskMetric:

  Optional metric ID displayed immediately after the existing Site Risk
  Score in the site overview. The column is omitted when the metric is
  absent from \`dfResults\`. Default: \`"Analysis_srs0002"\`.

- strComparisonRiskLabel:

  Column label for the comparison risk score. Default: \`"Review
  Priority Score"\` for dated action detail, otherwise \`"Adjusted Risk
  Score"\`. An explicit label is always preserved.

- strGroupSubset:

  Optional group subset passed to the report's group overview. \`NULL\`
  preserves the report default (\`"red"\` for site reports, \`"all"\`
  otherwise).

- dfRiskScoreDetail:

  Optional per-KRI detail behind the second risk score, from
  \[MakeActionRiskScoreDetail()\]. Clicking a score in that column lists
  each KRI's action evidence and whether it counts toward the score.
  Dated detail adds a border to each site/KRI cell with a recorded
  action within 90 days, without changing scores or flag colors. Ignored
  when the comparison metric is absent from \`dfResults\`. Default:
  \`NULL\`.

- lData:

  Optional workflow domain list. Used to obtain
  \`Analysis_ActionRiskScoreDetail\` when \`dfRiskScoreDetail\` is NULL.

## Value

File path of the saved report html is returned invisibly. Save to object
to view absolute output path.

## Details

Character ISO snapshot dates and identifiers are normalized at the
report boundary. An absent comparison metric leaves the original report
layout unchanged. Empty optional detail is treated as NULL; a present
score without detail warns and renders without its drilldown. Invalid
supplied detail or mismatched current group keys is an error.

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
