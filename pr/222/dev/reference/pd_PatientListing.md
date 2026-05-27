# Premature-death patient listing

\`r lifecycle::badge("experimental")\`

\`DT\` table of flagged premature-death subjects.

## Usage

``` r
pd_PatientListing(dfResults, dfDeath)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results containing patient-level rows.

- dfDeath:

  \`data.frame\` Mapped death data keyed on \`subjid\`.

## Value

A \`DT::datatable\` htmlwidget.
