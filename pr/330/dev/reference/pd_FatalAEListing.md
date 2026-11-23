# Premature-death fatal AE listing

\`r lifecycle::badge("experimental")\`

\`DT\` table of qualifying fatal adverse events for premature-death
participants. See \`pd_FatalAEListingData()\`.

## Usage

``` r
pd_FatalAEListing(dfResults, dfAE = NULL, dfSubjects = NULL)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results containing patient-level rows.

- dfAE:

  \`data.frame\` (optional) Mapped AE data with \`subjid\` and any of
  \`mdrpt_nsv\`, \`aest_dt\`, \`aeout\`, \`aetoxgr\`, \`aesdth\`,
  \`aereldrv\`, \`aerel\` and \`studyid\`. \`NULL\` yields an empty
  listing.

- dfSubjects:

  \`data.frame\` (optional) Mapped subject data with \`subjid\` and any
  of \`studyid\`, \`invid\` and \`country\`.

## Value

A \`DT::datatable\` htmlwidget.
