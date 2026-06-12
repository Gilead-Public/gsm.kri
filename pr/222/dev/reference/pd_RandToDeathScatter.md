# Randomization-to-death scatter

\`r lifecycle::badge("experimental")\`

Scatter of premature deaths: x = days from randomization to death
(\`death_dy\`), colored by premature-death bucket (\`\<=30d\` /
\`31-Wd\`) using the RAG colors of \[pd_BucketBar()\]. By default y =
group (categorical). When \`dSnapshotDate\` is supplied the y-axis
instead becomes numeric — days from randomization to the snapshot
(\`SnapshotDate − death_dt + death_dy\`), the full window the subject
would have been observed had they lived — for the study-level view,
where the categorical group axis would otherwise collapse to one row.
Country, site, subject, days to death, bucket, and treatment-related
status are surfaced in the hover tooltip.

## Usage

``` r
pd_RandToDeathScatter(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group",
  dSnapshotDate = NULL,
  strOuterCol = NULL
)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\`, \`death_dy\`, and
  optionally \`treatment_related\` (shown as "Unknown" when absent).
  When \`dSnapshotDate\` is supplied, \`death_dt\` is also required.

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

  \`Date\` (or coercible) When non-\`NULL\`, selects the study-level
  view: y becomes days from randomization to the snapshot. Default:
  \`NULL\` (categorical group y-axis).

- strOuterCol:

  \`character\` Optional parent column for a two-tier (multicategory)
  y-axis bracketing each group under its parent (e.g. "country" for
  sites). Ignored in the study view (numeric y). Default \`NULL\`.

## Value

A \`plotly\` htmlwidget.
