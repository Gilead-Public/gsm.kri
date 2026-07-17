# Premature-death reason distribution chart

\`r lifecycle::badge("experimental")\`

Horizontal bar of \`deathcls\` counts among premature deaths. Each bar
is labelled with its count (placed inside the bar, or just outside when
the bar is too narrow to hold the label).

## Usage

``` r
pd_ReasonDist(dfDeath, nWindowDays = 90, nEnrolled = NULL)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`deathcls\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

- nEnrolled:

  \`numeric\` Total enrolled subjects, used for the " tooltip line. When
  \`NULL\` (default) that line is omitted. Default: \`NULL\`.

## Value

A \`plotly\` htmlwidget.
