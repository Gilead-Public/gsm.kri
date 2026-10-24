# Record rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Level 2 of the vitals listing: the enrolled participants' \`Mapped_VS\`
records with every vital. \`repeat_vitals\` lists the vitals whose value
is in a repeat window on that record.

## Usage

``` r
rm_RecordRows(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`tibble\` with \`country\`, \`invid\`, \`subjid\`, \`visit\`,
\`vs_dt\`, \`vsperf_std\`, one column per vital, and the hidden
\`repeat_vitals\` column, ordered by participant and measurement order.
