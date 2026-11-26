# Discontinuation reason slices for the IP Monitoring reasons charts

\`r lifecycle::badge("experimental")\`

Splits each premature treatment discontinuation's comma-separated
reasons and counts the participant once under each reason. Every slice
lists every reason in \`order\`, zeros included, because gsm.viz drops
an ordered category that has no row. \`pct\` is over the dosed
participants in scope, which is the same for the All and Dosed filters.

## Usage

``` r
ipm_ReasonRows(dfIPM, bHasPTD)
```

## Arguments

- dfIPM:

  \`data.frame\` Output of \[ipm_ClassifyParticipants()\].

- bHasPTD:

  \`logical\` Whether premature treatment discontinuation data was
  delivered.

## Value

\`NULL\` when \`bHasPTD\` is \`FALSE\`; otherwise a \`list\` with
\`order\` (reasons by study-wide frequency, ties alphabetical),
\`study\`, \`country\[\[country\]\]\`,
\`site\[\[country\]\]\[\[invid\]\]\` and \`zero\` (the Not dosed
filter). Each slice is a \`tibble\` with \`reason\`, \`n\` and \`pct\`.
