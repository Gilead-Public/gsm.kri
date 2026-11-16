# Breakdown slices

\`r lifecycle::badge("experimental")\`

One row per key and fill value with the number of rows of \`dfRecords\`
in scope, for the study, each country and each country's sites. The
caller passes one row per participant, key and fill value. \`pct\` is
over enrolled participants in scope.

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

\`list\` with \`order\`, \`study\`, \`country\`, \`site\` (by country,
then site) and \`zero\`.
