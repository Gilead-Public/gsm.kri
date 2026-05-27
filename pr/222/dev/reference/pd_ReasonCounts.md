# Premature-death reason counts

\`r lifecycle::badge("experimental")\`

Counts \`death_reason\` among premature deaths (\`death_dy \<=
window\`). Falls back to \`"Unknown"\` for missing reasons or when the
\`death_reason\` column is absent.

## Usage

``` r
pd_ReasonCounts(dfDeath, nWindowDays = 90)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`death_reason\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

## Value

A \`data.frame\` with \`death_reason\` and \`n\` columns, sorted by
\`n\` descending.
