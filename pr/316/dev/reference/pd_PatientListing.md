# Premature-death patient listing

\`r lifecycle::badge("experimental")\`

\`DT\` table of flagged premature-death subjects.

## Usage

``` r
pd_PatientListing(
  dfResults,
  dfDeath,
  dfSubjects = NULL,
  dfExclusion = NULL,
  dfAE = NULL
)
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

- dfExclusion:

  \`data.frame\` (optional) Mapped exclusion data with \`subjid\` and
  \`Source\` (as produced by \`EXCLUSION.yaml\`). When supplied with a
  \`Source\` column, the output gains a three-valued
  \`eligibility_status\` column: \`"Ineligible"\` when \`Source !=
  "Neither"\` (matching the \`kri0014\` rule), \`"Eligible"\` when
  \`Source == "Neither"\`, and \`"Unknown"\` when the subject has no
  matching exclusion row.

- dfAE:

  \`data.frame\` (optional) Mapped AE data with \`subjid\`, \`aetoxgr\`,
  and \`aerel\` (\`"RELATED"\`/\`"NOT RELATED"\`). Used to compute the
  Treatment Related column: \`"Yes"\` when \`deathcls\` is an adverse
  event AND the subject has a fatal (\`aetoxgr==5\`) treatment-related
  AE; \`"No"\` when \`deathcls\` is an adverse event AND the subject has
  a fatal (\`aetoxgr==5\`) not-treatment-related AE, or when
  \`deathcls\` is not an AE AND there is no fatal treatment-related AE;
  \`"Unknown"\` otherwise (mixed signals, or missing \`deathcls\`/AE
  evidence). \`death_reason\` is \`deathcls\` (else \`"Unknown"\`).

## Value

A \`DT::datatable\` htmlwidget.
