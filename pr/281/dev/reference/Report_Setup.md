# Calculate needed values for report

\`r lifecycle::badge("stable")\`

## Usage

``` r
Report_Setup(dfGroups = NULL, dfMetrics = NULL, dfResults = NULL)
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- dfMetrics:

  \`data.frame\` Metric-specific metadata for use in charts and
  reporting. Created by passing an \`lWorkflow\` object to
  \[MakeMetric()\]. Expected columns: \`File\`, \`MetricID\`, \`Group\`,
  \`Abbreviation\`, \`Metric\`, \`Numerator\`, \`Denominator\`,
  \`Model\`, \`Score\`, and \`Threshold\`. For more details see the Data
  Model vignette: \`vignette("DataModel", package = "gsm.core")\`.

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

## Value

\`list\` with the following elements: - \`GroupLevel\` (character): The
group level of the report. - \`SnapshotDate\` (Date): The date of the
snapshot. - \`lStudy\` (list): Study-level metadata. - \`StudyID\`
(character): The study ID. - \`red_kris\` (numeric): The number of red
flags. - \`amber_kris\` (numeric): The number of amber flags.
