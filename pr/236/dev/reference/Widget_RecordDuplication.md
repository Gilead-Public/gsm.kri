# Record Duplication Widget

\`r lifecycle::badge("experimental")\`

An interactive htmlwidget that displays record duplication across
measurements, nested by Measure → Site → Participant. Duplicate records
are highlighted and summary statistics are shown at each level.

For the data preparation wrapper, see \[Report_RecordDuplication()\].

## Usage

``` r
Widget_RecordDuplication(
  dfFlagged,
  dfReportingResults = NULL,
  dfReportingMetrics = NULL,
  dfMeasureMetrics = NULL,
  strGroupLevel = "Site",
  vPrioritizedMeasures = NULL
)
```

## Arguments

- dfFlagged:

  \`data.frame\` Long-format data with columns: \`subjid\`, \`GroupID\`,
  \`date\`, \`measure\`, \`value\`, \`is_duplicate\`, \`is_source\`.

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

## Value

An htmlwidget for record duplication visualization.
