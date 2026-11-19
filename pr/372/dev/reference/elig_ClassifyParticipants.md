# Classify enrolled participants by eligibility status

\`r lifecycle::badge("experimental")\`

One row per enrolled participant of \`Mapped_EXCLUSION\` with exactly
one status: - \*\*Ineligible\*\*: \`Source != 'Neither'\` (rules 2.4 and
2.5, applied upstream); - \*\*Potentially Ineligible\*\* (pilot mode
only): otherwise, the \`edc_query\` or \`edc_pd\` flag is \`"Y"\` (rules
2.6 and 2.7, applied in the study repo); - \*\*No Eligibility Risk\*\*:
otherwise.

The flag sources never read \`Source\` values: the EDC eCRF flag is
\`ie_violation\`, the PD flag is \`pd_violation\`, or the presence of PD
terms (\`eligibility_criteria\`) when a study's EXCLUSION has no
\`pd_violation\`.

## Usage

``` r
elig_ClassifyParticipants(
  dfExclusion,
  dfGroups = NULL,
  strMode = c("basic", "pilot")
)
```

## Arguments

- dfExclusion:

  \`data.frame\` \`Mapped_EXCLUSION\`, optionally with the level 1
  columns \`pd_important\`, \`pd_nonimportant\`, \`edc_query\` and
  \`edc_pd\` (\`"Y"\`/\`"N"\`; \`NA\` throughout when the source is not
  delivered).

- dfGroups:

  \`data.frame\` Reporting groups. Site-level \`InvestigatorFirstName\`
  / \`InvestigatorLastName\` give the investigator. Default: \`NULL\`.

- strMode:

  \`character\` Mode resolved by \[elig_Mode()\]: \`"basic"\` (default)
  or \`"pilot"\`.

## Value

\`tibble\` with \`studyid\`, \`subjid\`, \`country\`, \`invid\`,
\`investigator\`, \`status\`, the \`flag\_\*\` columns of the delivered
sources (\`"Y"\`/\`"N"\`/\`NA\`), \`criteria\`, \`pd_dates\` and
\`pd_terms\`.
