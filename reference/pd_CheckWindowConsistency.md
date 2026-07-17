# Check premature-death window consistency

\`r lifecycle::badge("experimental")\`

Warns only when the report's \`nWindowDays\` disagrees with the window
used to produce \`dfResults\` – i.e. when the live premature-death count
in \`Mapped_Death\` (\`nPremature\`) differs from the number of
\`pat0015\` \`Flag == 2\` rows (\`nFlagged\`). When the counts agree it
returns invisibly without warning, so callers (e.g. the report) just
call it unconditionally.

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

Called for its side-effect (warning on mismatch); returns \`NULL\`
invisibly.
