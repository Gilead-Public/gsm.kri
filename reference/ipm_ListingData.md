# Participant listing rows for the IP Monitoring report

\`r lifecycle::badge("experimental")\`

One row per participant in status stack order, then participant ID. The
\`dosed\` column is hidden in the table and drives its dosed filter.

## Usage

``` r
ipm_ListingData(dfIPM)
```

## Arguments

- dfIPM:

  \`data.frame\` Output of \[ipm_ClassifyParticipants()\].

## Value

A \`tibble\` with the listing columns in display order.
