# IP Compliance overview figures

\`r lifecycle::badge("experimental")\`

The ten study-wide overview figures in report order. Non-starter figures
are shares of enrolled participants; the four treatment completion
statuses are shares of dosed participants.

## Usage

``` r
ipc_OverviewStats(dfIPC, bHasPTD)
```

## Arguments

- dfIPC:

  \`data.frame\` Output of \[ipc_ClassifyParticipants()\].

- bHasPTD:

  \`logical\` Whether \`drv_drg_completion\` was delivered. When
  \`FALSE\`, the four treatment completion figures are \`NA\`.

## Value

A \`tibble\` with \`label\`, \`n\`, \`pct\` (\`NA\` for a zero
denominator) and \`base\` (\`"enrolled"\`, \`"dosed"\`, or \`NA\` for
Total enrolled).
