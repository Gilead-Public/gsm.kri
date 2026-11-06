# Reconcile the Repeat Measurements report with the kri0020/cou0020 metrics

\`r lifecycle::badge("experimental")\`

Sums participant numerators and denominators per KRI measure and
compares them with the site-level \`kri0020a\`–\`f\` and country-level
\`cou0020a\`–\`f\` results of the latest snapshot.

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

A \`tibble\` with \`vital\`, \`metric\` (\`kri0020\*\` or
\`cou0020\*\`), \`Numerator\`, \`Denominator\`, \`kri_Numerator\`,
\`kri_Denominator\` and \`match\`, one row per KRI measure and metric
with results, site before country; \`NULL\` when \`dfResults\` has no
\`kri0020\` or \`cou0020\` results.
