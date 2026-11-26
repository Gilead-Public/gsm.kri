# Eligibility status counts of a snapshot

\`r lifecycle::badge("experimental")\`

Participants per study and status, classified as the report does. A
pilot study saves it every snapshot as \`Reporting_EligStatus\`; the
snapshots together are the report's \`dfStatusHistory\`.

## Usage

``` r
elig_StatusCounts(dfExclusion, strMode = c("basic", "pilot"))
```

## Arguments

- dfExclusion:

  \`data.frame\` \`Mapped_EXCLUSION\`, optionally with the level 1
  columns \`pd_important\`, \`pd_nonimportant\`, \`edc_query\` and
  \`edc_pd\` (\`"Y"\`/\`"N"\`; \`NA\` throughout when the source is not
  delivered), and \`iecat_concat\`, the category (\`"IN"\`/\`"EX"\`) of
  each code in \`ietestcd_concat\` order; without it the criteria are
  not split by type.

- strMode:

  \`character\` \`"basic"\` (default) or \`"pilot"\`, resolved by
  \[elig_Mode()\].

## Value

\`tibble\` with \`GroupLevel\` (\`"Study"\`), \`GroupID\` (study ID),
\`Status\` and \`n\`.
