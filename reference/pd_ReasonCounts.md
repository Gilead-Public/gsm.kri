# Premature-death reason counts

\`r lifecycle::badge("experimental")\`

Counts \`deathcls\` among premature deaths (\`death_dy \<= window\`).
Falls back to \`"Unknown"\` for missing reasons or when the \`deathcls\`
column is absent.

## Usage

``` r
pd_ReasonCounts(dfDeath, nWindowDays = 90)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`deathcls\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

## Value

A \`data.frame\` with \`death_reason\` and \`n\` columns, sorted by
\`n\` descending.
