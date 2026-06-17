# Premature-death patient listing data

\`r lifecycle::badge("experimental")\`

Filters \`dfResults\` to flagged patient-level premature-death rows
(\`MetricID == "Analysis_pat0015"\`, \`Flag == 2\`) and joins
\`Mapped_Death\` detail. Sorted by \`death_dy\` ascending. Missing
\`death_reason\` degrades to \`"Unknown"\`. The \`treatment_related\`
display column (LIST-1) is derived from the death class (\`deathcls\`)
and AE relatedness (\`aerel\`): \`"Yes"\` iff the class is an Adverse
Event (case-insensitive \`"Adverse Event"\` / \`"AE"\`) \*\*and\*\*
\`aerel == "Yes"\` (case-insensitive); \`"Unknown"\` when the class or
relatedness is missing; otherwise \`"No"\`. The raw \`deathcls\` /
\`aerel\` columns are dropped. A \`randomization_date\` column is
derived as \`death_dt - death_dy\`, reconstructing the randomization
date (\`rgmn_dt\`) that \`death_dy\` was counted from.

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
  \`invid\`, and optionally \`studyid\` / \`country\`. When supplied,
  the output includes \`studyid\` (when present, as the leftmost
  column), \`invid\`, and \`country\` (when present) as visible columns
  for study-, site-, and country-level filtering in the interactive
  report.

## Value

A \`data.frame\` of one row per flagged premature-death subject.
