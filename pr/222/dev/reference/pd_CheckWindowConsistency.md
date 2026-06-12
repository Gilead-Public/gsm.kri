# Check premature-death window consistency

\`r lifecycle::badge("experimental")\`

Emits a warning when the report's \`nWindowDays\` disagrees with the
window used to produce \`dfResults\` (detected by comparing the live
premature-death count in \`Mapped_Death\` against the number of
\`pat0015\` \`Flag == 2\` rows).

## Usage

``` r
pd_CheckWindowConsistency(nWindowDays, nPremature, nFlagged)
```

## Arguments

- nWindowDays:

  \`numeric\` Window days passed to the report.

- nPremature:

  \`integer\` Count of premature deaths in \`Mapped_Death\`.

- nFlagged:

  \`integer\` Count of flagged \`pat0015\` rows in \`dfResults\`.

## Value

Called for its side-effect (warning); returns \`NULL\` invisibly.
