# Long rows for the reason bar chart

\`r lifecycle::badge("experimental")\`

Flattens a reason slice into the long data frame the \`gsm.viz\` reason
widget consumes.

## Usage

``` r
pd_ReasonRows(slice)
```

## Arguments

- slice:

  A \`list(reason, n, hover)\` from \`pd_ReasonSlice\` /
  \[pd_ReasonByCountry()\].

## Value

A \`data.frame\` with \`reason\`, \`n\`, and \`hover\` columns.
