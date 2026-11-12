# Group-level visualization of scores.

\`r lifecycle::badge("stable")\`

## Usage

``` r
Visualize_Score(
  dfResults,
  vThreshold = NULL,
  strType = "Metric",
  bFlagFilter = FALSE,
  strTitle = ""
)
```

## Arguments

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

- vThreshold:

  \`numeric\` Threshold specification, a vector of length 2 that
  defaults to NULL.

- strType:

  \`character\` One of \`"KRI"\` or \`"score"\`.

- bFlagFilter:

  \`logical\` Filter out non-flagged groups? Default: \`FALSE\`

- strTitle:

  \`character\` Title of plot.

## Value

group-level ggplot2 object.

## Examples

``` r
## Filter data to one metric and snapshot
reportingResults_filter <- gsm.core::reportingResults %>%
  dplyr::filter(MetricID == "Analysis_kri0001" & SnapshotDate == max(SnapshotDate))
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.

Visualize_Score(dfResults = reportingResults_filter)
#> Error: object 'reportingResults_filter' not found

## Only show Flagged Groups
Visualize_Score(
  dfResults = reportingResults_filter,
  bFlagFilter = TRUE
)
#> Error: object 'reportingResults_filter' not found

## Custom Title
Visualize_Score(
  dfResults = reportingResults_filter,
  strTitle = "Custom Title"
)
#> Error: object 'reportingResults_filter' not found
```
