# Overview summary statistics for the premature-death report

\`r lifecycle::badge("experimental")\`

Computes the four headline numbers shown in the report's Overview table
from the single classified-cohort source of truth (\[pd_Classify()\]
output), so the table cannot drift from the bucket bars and scatter.
"Premature" is the union of the two death categories (the \`death30\` /
\`death3190\` keys of \[pd_CategoryLevels()\]); the ineligible share is
taken over that same premature set, so numerator and denominator always
describe one cohort.

## Usage

``` r
pd_OverviewStats(dfClassified, dfExclusion = NULL, nWindowDays = 90)
```

## Arguments

- dfClassified:

  \`data.frame\` Output of \[pd_Classify()\]: one row per enrolled
  (randomized) subject, with \`subjid\`, \`invid\`, and \`Category\`.

- dfExclusion:

  \`data.frame\` (optional) Mapped exclusion data with \`subjid\` and
  \`Source\` (as produced by \`EXCLUSION.yaml\`). When absent (or
  lacking a \`Source\` column), \`has_eligibility\` is \`FALSE\` and the
  ineligible counts are \`NA\` (the report renders the cell as a dash
  rather than asserting zero).

- nWindowDays:

  \`numeric\` Premature-death window in days. Default 90.

## Value

A named \`list\`: \`nEnrolled\`, \`nSites\`, \`nPremature\`,
\`nPrematureRate\`, \`nIneligible\`, \`nIneligibleRate\`,
\`has_eligibility\`, \`nDeath30\` (subjects who died within 30 days),
\`nDeath3190\` (subjects who died within 31-90 days). Invariant:
\`nDeath30 + nDeath3190 == nPremature\`.
