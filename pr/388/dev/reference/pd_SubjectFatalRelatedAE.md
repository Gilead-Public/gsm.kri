# Per-subject fatal treatment-related AE flag

\`r lifecycle::badge("experimental")\`

For each subject in \`dfAE\`, whether they have at least one adverse
event that is both fatal and treatment-related, fatal and not
treatment-related, or fatal with unknown relatedness — the AE-side
signals for the premature-death Treatment Related column. Centralizing
the rules keeps them in one tested place.

An AE is fatal when its outcome is fatal (\`aeout == "Fatal"\`), it is
graded CTCAE 5 (\`aetoxgr == 5\`), or it is flagged as resulting in
death (\`aesdth == "Yes"\`). Relatedness comes from \`aereldrv\`
(\`"Yes"\` / \`"No"\`), falling back to \`aerel\` (\`"RELATED"\` /
\`"NOT RELATED"\`) when \`aereldrv\` is absent or missing. Comparisons
are case-insensitive and NA-safe: a missing field never makes an AE
fatal or related.

## Usage

``` r
pd_SubjectFatalRelatedAE(dfAE)
```

## Arguments

- dfAE:

  \`data.frame\` Mapped AE data with \`subjid\` and any of \`aeout\`,
  \`aetoxgr\`, \`aesdth\`, \`aereldrv\` and \`aerel\`.

## Value

A \`tibble\` with one row per subject: \`subjid\` and the logicals
\`has_fatal_related_ae\`, \`has_fatal_unrelated_ae\` and
\`has_fatal_unknown_ae\` (a fatal AE with missing relatedness).
