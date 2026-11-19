# Status over time rows

One bar per snapshot of the study's status history.

## Usage

``` r
elig_TrendRows(dfStatusHistory)
```

## Arguments

- dfStatusHistory:

  \`data.frame\` Rows of \[elig_StatusCounts()\] from every snapshot,
  with \`SnapshotDate\`, or \`NULL\`.

## Value

\`tibble\` with \`GroupID\` (snapshot date), \`Status\` and \`n\`.
