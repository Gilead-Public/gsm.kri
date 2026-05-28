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
  dfMetrics = NULL,
  strGroupLevel = "Site",
  vPrioritizedMeasures = NULL
)
```

## Arguments

- dfFlagged:

  \`data.frame\` Long-format data with columns: \`subjid\`, \`GroupID\`,
  \`date\`, \`measure\`, \`value\`, \`is_duplicate\`.

- dfMetrics:

  \`data.frame\` Optional metric metadata to identify prioritized
  measures. Should have a \`Metric\` or \`Abbreviation\` column.

- strGroupLevel:

  \`character\` Group level label. Default: \`"Site"\`.

- vPrioritizedMeasures:

  \`character\` Vector of measure names that have KRI metrics
  configured. These are displayed first with a priority indicator.

## Value

An htmlwidget for record duplication visualization.
