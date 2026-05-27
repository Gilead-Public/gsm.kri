# Randomization-to-death scatter

\`r lifecycle::badge("experimental")\`

Scatter of premature deaths: x = days from randomization to death
(\`death_dy\`). Subjects who died after the window are excluded.

By default y = group and colour = \`treatment_related\` (degrading to a
single uncoloured series when \`treatment_related\` is absent, e.g.
before the gsm.mapping \`complete_death()\` extension lands). When
\`dSnapshotDate\` is supplied the y-axis instead becomes numeric — days
from randomization to the snapshot date (\`SnapshotDate - death_dt +
death_dy\`) — and points are coloured by premature-death bucket
(\`\<=30d\` / \`31-Wd\`), reusing the RAG colours of \[pd_BucketBar()\].
This is the study-level view, where the categorical group axis would
otherwise collapse to a single row.

## Usage

``` r
pd_RandToDeathScatter(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group",
  dSnapshotDate = NULL
)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`treatment_related\`. When \`dSnapshotDate\` is supplied,
  \`death_dt\` is also required.

- dfSubjects:

  \`data.frame\` Mapped subject data with \`subjid\` and
  \`strGroupCol\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

- strGroupCol:

  \`character\` Column in \`dfSubjects\` to group by. Default: "invid".

- strGroupLabel:

  \`character\` Axis label for the group dimension. Default: "Group".

- dSnapshotDate:

  \`Date\` (or coercible) Snapshot date. When non-\`NULL\`, switches the
  y-axis to numeric days-from-randomization-to-snapshot and colours by
  bucket. Default: \`NULL\` (categorical group y-axis).

## Value

A \`plotly\` htmlwidget.
