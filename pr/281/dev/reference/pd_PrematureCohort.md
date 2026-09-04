# Premature-death cohort

\`r lifecycle::badge("experimental")\`

The single definition of "premature death within the window": the rows
of \`dfDeath\` whose \`death_dy\` is non-missing and at or before
\`nWindowDays\`. When \`dfSubjects\` is supplied, each death is
left-joined to its subject's identity columns (\`studyid\` / \`country\`
/ \`invid\`, whichever are present) so callers can group or filter by
site and country. Centralizing the predicate keeps the scatter, reason
counts, and the report agreeing on what counts as premature.

## Usage

``` r
pd_PrematureCohort(dfDeath, dfSubjects = NULL, nWindowDays = 90)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\` and \`death_dy\`.

- dfSubjects:

  \`data.frame\` (optional) Mapped subject data keyed on \`subjid\`.
  When supplied, its \`studyid\` / \`country\` / \`invid\` columns
  (those present) are joined onto each death. Default: \`NULL\` (no
  join).

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

## Value

A \`data.frame\` of the premature \`dfDeath\` rows, with subject
identity columns appended when \`dfSubjects\` is supplied.
