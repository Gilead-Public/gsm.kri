# Generate Record Duplication Report

\`r lifecycle::badge("experimental")\`

Convenience function that runs \[Detect_ConsecutiveRepeats()\] across
multiple measures and produces a \[Widget_RecordDuplication()\]
htmlwidget. Supports both wide-format vitals data and long-format lab
data.

The report uses the same rolling-window detection as the
\[Count_Duplicates()\] metric workflow, so a run highlighted here is
exactly a run that contributes repeat windows to the metric.

## Usage

``` r
Report_RecordDuplication(
  dfMappedVS = NULL,
  dfMappedLB = NULL,
  dfMappedSUBJ,
  vMeasuresVS = NULL,
  vMeasuresLB = NULL,
  vPrioritizedMeasures = NULL,
  nWindowLength = 3,
  strGroupCol = "invid",
  strGroupLevel = "Site",
  dfReportingResults = NULL,
  dfReportingMetrics = NULL
)
```

## Arguments

- dfMappedVS:

  \`data.frame\` Optional. Wide-format vitals data with measurement
  columns (e.g., weight, sysbp, diabp).

- dfMappedLB:

  \`data.frame\` Optional. Long-format lab data with measure identifier
  and numeric result columns.

- dfMappedSUBJ:

  \`data.frame\` Subject-level data with \`subjid\` and group columns.

- vMeasuresVS:

  \`character\` Vital sign columns to analyze. Default: all numeric
  columns in \`dfMappedVS\` except identifiers.

- vMeasuresLB:

  \`character\` Lab test names to analyze. Default: all unique values in
  \`lbtstnam\` column.

- vPrioritizedMeasures:

  \`character\` Measures with KRI metrics configured (shown first). If
  NULL and \`dfMeasureMetrics\` is derived from installed YAMLs,
  defaults to those measures.

- nWindowLength:

  \`numeric\` Rolling window length \*W\* used to detect consecutive
  repeats. Should match the \`WindowLength\` configured on the metric
  YAMLs. Default: \`3\`.

- strGroupCol:

  \`character\` Column in \`dfMappedSUBJ\` for grouping. Default:
  \`"invid"\`.

- strGroupLevel:

  \`character\` Group level label. Default: \`"Site"\`.

- dfReportingResults:

  \`data.frame\` Optional. Standard reportingResults data with columns:
  \`GroupID\`, \`GroupLevel\`, \`MetricID\`, \`Score\`, \`Flag\`. Passed
  to widget to show metric badges.

- dfReportingMetrics:

  \`data.frame\` Optional. Standard reportingMetrics data with columns:
  \`MetricID\`, \`Metric\`. Passed through to widget for future use.

## Value

A \[Widget_RecordDuplication()\] htmlwidget.

## Examples

``` r
if (FALSE) { # \dontrun{
Report_RecordDuplication(
  dfMappedVS = lData$Mapped_VS,
  dfMappedSUBJ = lData$Mapped_SUBJ,
  vPrioritizedMeasures = c("weight")
)
} # }
```
