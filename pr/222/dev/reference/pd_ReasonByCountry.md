# Premature-death reason counts by country

\`r lifecycle::badge("experimental")\`

Reason (\`deathcls\`) counts among premature deaths, split per country,
plus an \`"\_\_ALL\_\_"\` aggregate over every premature death. Powers
the country-reactive Reasons chart: the report serializes this to JSON
and a client handler swaps the bar to the clicked country's slice. Each
slice is sorted by descending count and carries a prebuilt hover string,
so the client needs no arithmetic.

## Usage

``` r
pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`deathcls\`.

- dfSubjects:

  \`data.frame\` Mapped subject data with \`subjid\` and \`country\`,
  joined onto each death to attribute it to a country.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

## Value

A named \`list\`: one element per country (and \`"\_\_ALL\_\_"\`), each
a \`list\` with \`reason\`, \`n\`, and \`hover\` vectors sorted by
descending \`n\`.
