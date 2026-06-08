# Premature-death patient listing data

\`r lifecycle::badge("experimental")\`

Filters \`dfResults\` to flagged patient-level premature-death rows
(\`MetricID == "Analysis_pat0015"\`, \`Flag == 2\`) and joins
\`Mapped_Death\` detail. Sorted by \`death_dy\` ascending. Missing
\`death_reason\` / \`treatment_related\` columns degrade to
\`"Unknown"\` / \`NA\`.

## Usage

``` r
pd_PatientListingData(dfResults, dfDeath, dfSubjects = NULL)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results containing patient-level rows.

- dfDeath:

  \`data.frame\` Mapped death data keyed on \`subjid\`.

- dfSubjects:

  \`data.frame\` (optional) Mapped subject data with \`subjid\`,
  \`invid\`, and optionally \`country\`. When supplied, the output
  includes \`invid\` (and \`country\` when present) as visible columns
  for site- and country-level filtering in the interactive report.

## Value

A \`data.frame\` of one row per flagged premature-death subject.
