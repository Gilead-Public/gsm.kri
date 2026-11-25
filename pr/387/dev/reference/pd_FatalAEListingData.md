# Premature-death fatal AE listing data

\`r lifecycle::badge("experimental")\`

One row per qualifying fatal adverse event for participants in the
premature-death population (\`MetricID == "Analysis_pat0015"\`, \`Flag
== 2\` in \`dfResults\`). An AE qualifies when it is fatal as defined by
\`pd_SubjectFatalRelatedAE()\`: fatal outcome (\`aeout\`), CTCAE grade 5
(\`aetoxgr\`) or resulted in death (\`aesdth\`).

Only identifiers, the MedDRA preferred term, start date, outcome and
relatedness are returned; other AE fields (e.g. cause of death text,
drug names) never reach the listing. Missing outcome or relatedness is
shown as \`"Unknown"\`.

## Usage

``` r
pd_FatalAEListingData(dfResults, dfAE = NULL, dfSubjects = NULL)
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

A \`data.frame\` with \`studyid\`, \`subjid\`, \`country\`, \`invid\`
(each when available), \`mdrpt_nsv\`, \`aest_dt\`, \`aeout\` and
\`treatment_related\` (\`"Yes"\` / \`"No"\` / \`"Unknown"\`), sorted by
\`subjid\` and \`aest_dt\`.
