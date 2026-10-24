# Reconcile the Repeat Measurements report with the kri0020 metrics

\`r lifecycle::badge("experimental")\`

Sums participant numerators and denominators per KRI vital and compares
them with the site-level \`kri0020a\`–\`f\` results of the latest
snapshot.

## Usage

``` r
rm_Reconcile(dfParticipants, dfResults)
```

## Arguments

- dfParticipants:

  \`data.frame\` \`participants\` from \[rm_Classify()\].

- dfResults:

  \`data.frame\` Reporting results.

## Value

A \`tibble\` with \`vital\`, \`metric\`, \`Numerator\`, \`Denominator\`,
\`kri_Numerator\`, \`kri_Denominator\` and \`match\`, one row per KRI
vital with results; \`NULL\` when \`dfResults\` has no \`kri0020\`
results.
