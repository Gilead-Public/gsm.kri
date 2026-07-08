# Helper function to create charts for multiple metrics

\`r lifecycle::badge("stable")\`

## Usage

``` r
MakeCharts(dfResults, dfMetrics, dfGroups, dfBounds, bDebug = FALSE, ...)
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

- bDebug:

  \`logical\` Print debug messages? Default: \`FALSE\`.

- ...:

  Additional chart configuration settings.

## Value

A list of charts for each metric.
