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
  \`invid\`, and optionally \`studyid\` / \`country\`. When supplied,
  the output includes \`studyid\` (when present, as the leftmost
  column), \`invid\`, and \`country\` (when present) as visible columns
  for study-, site-, and country-level filtering in the interactive
  report.

## Value

A \`DT::datatable\` htmlwidget.
