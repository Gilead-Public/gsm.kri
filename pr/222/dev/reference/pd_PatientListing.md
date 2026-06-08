# Premature-death patient listing

\`r lifecycle::badge("experimental")\`

\`DT\` table of flagged premature-death subjects.

## Usage

``` r
pd_PatientListing(dfResults, dfDeath, dfSubjects = NULL)
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

A \`DT::datatable\` htmlwidget.
