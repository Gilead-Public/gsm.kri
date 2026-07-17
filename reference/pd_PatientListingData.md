# Premature-death patient listing data

\`r lifecycle::badge("experimental")\`

Filters \`dfResults\` to flagged patient-level premature-death rows
(\`MetricID == "Analysis_pat0015"\`, \`Flag == 2\`) and joins
\`Mapped_Death\` detail. Sorted by \`death_dy\` ascending.
\`death_reason\` is the death classification (\`deathcls\`), falling
back to \`"Unknown"\` when absent. \`treatment_related\` is
three-valued: \`"Yes"\` when \`deathcls\` is an adverse event AND the
subject has a fatal (grade 5) treatment-related AE in \`dfAE\`; \`"No"\`
when \`deathcls\` is an adverse event AND the subject has a fatal (grade
5) not-treatment-related AE, or when \`deathcls\` is not an adverse
event AND no fatal treatment-related AE exists; \`"Unknown"\` otherwise
(mixed signals, or missing \`deathcls\`/AE evidence). A
\`randomization_date\` column is derived as \`death_dt - death_dy\`,
reconstructing the randomization date (\`rgmn_dt\`) that \`death_dy\`
was counted from.

## Usage

``` r
pd_PatientListingData(
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

A \`data.frame\` of one row per flagged premature-death subject.
