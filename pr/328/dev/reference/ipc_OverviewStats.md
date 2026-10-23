# IP Compliance overview figures

\`r lifecycle::badge("experimental")\`

The nine study-wide overview figures in report order. Non-starter
figures are shares of enrolled participants; Ongoing, Study complete and
Premature treatment discontinuation are shares of dosed participants.

## Usage

``` r
ipc_OverviewStats(dfIPC, bHasPTD)
```

## Arguments

- dfIPC:

  \`data.frame\` Output of \[ipc_ClassifyParticipants()\].

- bHasPTD:

  \`logical\` Whether premature treatment discontinuation data was
  delivered. When \`FALSE\`, that figure is \`NA\`.

## Value

A \`tibble\` with \`label\`, \`n\`, \`pct\` (\`NA\` for a zero
denominator) and \`base\` (\`"enrolled"\`, \`"dosed"\`, or \`NA\` for
Total enrolled).
