# Create message describing study summary for Report

\`r lifecycle::badge("stable")\`

## Usage

``` r
Report_OverviewText(lSetup, dfResults, lStudy)
```

## Arguments

- lSetup:

  \`list\` that is produced by \`Report_StudyInfo()\`.

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

- lStudy:

  \`list\` contains study-level metadata.
