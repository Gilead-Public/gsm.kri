# Per-subject fatal treatment-related AE flag

\`r lifecycle::badge("experimental")\`

For each subject in \`dfAE\`, whether they have at least one adverse
event that is both fatal (\`aetoxgr == 5\`) and treatment-related
(\`aerel == "RELATED"\`, case-insensitive). Also flags fatal (\`aetoxgr
== 5\`) not-treatment-related (\`aerel == "NOT RELATED"\`) AEs — the
AE-side signal for the "No" case in the premature-death Treatment
Related column. Centralizing both rules keeps them in one tested place.

Comparisons are NA-safe: a row with a missing grade or relatedness does
not qualify and never flips a subject to \`TRUE\`.

## Usage

``` r
pd_SubjectFatalRelatedAE(dfAE)
```

## Arguments

- dfAE:

  \`data.frame\` Mapped AE data with \`subjid\`, \`aetoxgr\` (integer
  CTCAE grade) and \`aerel\` (\`"RELATED"\` / \`"NOT RELATED"\`).

## Value

A \`tibble\` with one row per subject: \`subjid\`, a logical
\`has_fatal_related_ae\` (a fatal grade-5 \`"RELATED"\` AE), and a
logical \`has_fatal_unrelated_ae\` (a fatal grade-5 \`"NOT RELATED"\`
AE).
