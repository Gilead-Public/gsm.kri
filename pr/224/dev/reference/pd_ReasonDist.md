# Premature-death reason distribution chart

\`r lifecycle::badge("experimental")\`

Horizontal bar of \`death_reason\` counts among premature deaths.

## Usage

``` r
pd_ReasonDist(dfDeath, nWindowDays = 90)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`death_reason\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

## Value

A \`plotly\` htmlwidget.
