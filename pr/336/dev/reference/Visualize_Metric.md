# Visualize_Metric Function

\`r lifecycle::badge("stable")\`

The function creates all available charts for a metric using the data
provided

## Usage

``` r
Visualize_Metric(
  dfResults = dfResults,
  dfMetrics = NULL,
  dfGroups = NULL,
  dfBounds = NULL,
  strMetricID = NULL,
  strSnapshotDate = NULL,
  bDebug = FALSE,
  ...
)
```

## Arguments

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

- dfBounds:

  \`data.frame\` Set of predicted percentages/rates and upper- and
  lower-bounds across the full range of sample sizes/total exposure
  values for reporting. Created by passing \`dfResults\` and
  \`dfMetrics\` to \[MakeBounds()\]. Expected columns: \`Threshold\`,
  \`Denominator\`, \`Numerator\`, \`Metric\`, \`MetricID\`, \`StudyID\`,
  \`SnapshotDate\`.

- strMetricID:

  \`character\` MetricID to subset the data.

- strSnapshotDate:

  \`character\` Snapshot date to subset the data.

- bDebug:

  \`logical\` Display console in html viewer for debugging. Default is
  \`FALSE\`.

- ...:

  Additional chart configuration settings.

## Value

A list containing the following charts: - scatterPlot: A scatter plot
using JavaScript. - barChart: A bar chart using JavaScript with metric
on the y-axis. - timeSeries: A time series chart using JavaScript with
score on the y-axis. - metricTable: A table containing all

## Examples

``` r
lCharts <- Visualize_Metric(
  dfResults = gsm.core::reportingResults,
  dfBounds = gsm.core::reportingBounds,
  dfGroups = gsm.core::reportingGroups,
  dfMetrics = gsm.core::reportingMetrics,
  strMetricID = "Analysis_kri0001"
)
#> Parsed -2,-1,2,3 to numeric vector: -2, -1, 2, 3
```
