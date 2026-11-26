# Breakdown slices

\`r lifecycle::badge("experimental")\`

One row per key and fill value with at least one row of \`dfRecords\` in
scope, for the study, each country and each country's sites, so a chart
draws no empty category. The caller passes one row per participant, key
and fill value. \`pct\` is over enrolled participants in scope.

## Usage

``` r
elig_BreakdownRows(dfElig, dfRecords, vOrder, vStatuses)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- dfRecords:

  \`data.frame\` with \`subjid\`, \`key\` and \`status\`.

- vOrder:

  \`character\` Key order.

- vStatuses:

  \`character\` Fill values, in stack order.

## Value

\`list\` with \`order\`, \`study\`, \`country\` and \`site\` (by
country, then site). \`pct\` is rounded to 1 decimal.
