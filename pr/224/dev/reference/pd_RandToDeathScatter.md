# Randomization-to-death scatter

\`r lifecycle::badge("experimental")\`

Scatter of premature deaths: x = days from randomization to death
(\`death_dy\`), y = group, colour = \`treatment_related\`. Subjects who
died after the window are excluded. Degrades to a single uncoloured
series when \`treatment_related\` is absent (e.g. before the gsm.mapping
\`complete_death()\` extension lands).

## Usage

``` r
pd_RandToDeathScatter(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group"
)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`treatment_related\`.

- dfSubjects:

  \`data.frame\` Mapped subject data with \`subjid\` and
  \`strGroupCol\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

- strGroupCol:

  \`character\` Column in \`dfSubjects\` to group by. Default: "invid".

- strGroupLabel:

  \`character\` Axis label for the group dimension. Default: "Group".

## Value

A \`plotly\` htmlwidget.
