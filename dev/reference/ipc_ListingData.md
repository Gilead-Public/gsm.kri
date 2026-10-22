# Participant listing rows for the IP Compliance report

\`r lifecycle::badge("experimental")\`

One row per participant in status stack order, then participant ID. The
\`dosed\` column is hidden in the table and drives its dosed filter.

## Usage

``` r
ipc_ListingData(dfIPC)
```

## Arguments

- dfIPC:

  \`data.frame\` Output of \[ipc_ClassifyParticipants()\].

## Value

A \`tibble\` with the listing columns in display order.
