# Premature-death patient listing data

\`r lifecycle::badge("experimental")\`

Filters \`dfResults\` to flagged patient-level premature-death rows
(\`MetricID == "Analysis_pat0015"\`, \`Flag == 2\`) and joins
\`Mapped_Death\` detail. Sorted by \`death_dy\` ascending. Missing
\`death_reason\` / \`treatment_related\` columns degrade to
\`"Unknown"\` / \`NA\`.

## Usage

``` r
pd_PatientListingData(dfResults, dfDeath)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results containing patient-level rows.

- dfDeath:

  \`data.frame\` Mapped death data keyed on \`subjid\`.

## Value

A \`data.frame\` of one row per flagged premature-death subject.
