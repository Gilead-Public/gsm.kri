# Premature-death bucket bar chart

\`r lifecycle::badge("experimental")\`

Stacked bar of premature-death bucket counts per group. Each point's
\`customdata\` carries \`\[count, pct\]\` (pct = the bucket's share of
its group's enrolled subjects), so the report can toggle the y-axis
between counts and percentages client-side without recomputation.
Permanent on-bar labels (\`Bucket: N (P independent of the toggle's
\`customdata\`.

## Usage

``` r
pd_BucketBar(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
  strOuterCol = NULL
)
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\` and \`death_dy\`.

- dfSubjects:

  \`data.frame\` Mapped subject data with \`subjid\` and
  \`strGroupCol\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

- strGroupCol:

  \`character\` Column in \`dfSubjects\` to group by. Default:
  "studyid".

- strGroupLabel:

  \`character\` Axis label for the group dimension. Default: "Group".

- strOuterCol:

  \`character\` Optional parent column for a two-tier (multicategory)
  x-axis bracketing each group under its parent (e.g. "country" for
  sites). \`NULL\` (default) renders the flat one-tier bar.

## Value

A \`plotly\` htmlwidget.
