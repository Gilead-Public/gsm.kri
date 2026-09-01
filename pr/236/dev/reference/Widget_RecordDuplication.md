# Record Duplication Widget

\`r lifecycle::badge("experimental")\`

An interactive htmlwidget that displays consecutive repeated measures
across measurements, nested by Measure → Site → Participant. Records
belonging to a run of \`nWindowLength\` or more identical consecutive
values are highlighted, and repeat window rates are shown at each level.

For the data preparation wrapper, see \[Report_RecordDuplication()\].

## Usage

``` r
Widget_RecordDuplication(
  dfFlagged,
  dfReportingResults = NULL,
  dfReportingMetrics = NULL,
  dfMeasureMetrics = NULL,
  strGroupLevel = "Site",
  vPrioritizedMeasures = NULL,
  nWindowLength = 3
)
```

## Arguments

- dfFlagged:

  \`data.frame\` Long-format data with columns: \`subjid\`, \`GroupID\`,
  \`date\`, \`measure\`, \`value\`, \`RunID\`, \`RunLength\`,
  \`IsRepeatRun\`, \`IsEvaluableWindow\`, and \`IsRepeatWindow\`, as
  produced by \[Detect_ConsecutiveRepeats()\].

- dfReportingResults:

  \`data.frame\` Optional. Standard reportingResults data with columns:
  \`GroupID\`, \`GroupLevel\`, \`MetricID\`, \`Score\`, \`Flag\`. Used
  to show metric badges in group headers.

- dfReportingMetrics:

  \`data.frame\` Optional. Standard reportingMetrics data with columns:
  \`MetricID\`, \`Metric\`. Currently passed through for future use.

- dfMeasureMetrics:

  \`data.frame\` Optional. Maps measure names to MetricIDs; columns:
  \`measure\` (character), \`MetricID\` (character). Used to link
  measures to metric results.

- strGroupLevel:

  \`character\` Group level label. Default: \`"Site"\`.

- vPrioritizedMeasures:

  \`character\` Vector of measure names that have KRI metrics
  configured. These are displayed first with a priority indicator.

- nWindowLength:

  \`numeric\` Rolling window length \*W\* used to produce \`dfFlagged\`.
  Displayed in the header so the highlighting rule is self-describing.
  Default: \`3\`.

## Value

An htmlwidget for record duplication visualization.
