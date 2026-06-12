# Premature-death bucket bar chart

\`r lifecycle::badge("experimental")\`

Stacked bar of premature-death bucket counts per group. Each point's
\`customdata\` carries \`\[count, pct\]\` (pct = the bucket's share of
its group's enrolled subjects), so the report can toggle the y-axis
between counts and percentages client-side without recomputation.
Two-tier (nested) charts extend \`customdata\` to \`\[count, pct, group,
parent\]\` and name the group – and, when \`strOuterLabel\` is set, its
parent – in the hover tooltip; the flat chart's single labelled axis
already identifies the bar, so its tooltip stays minimal. Permanent
on-bar labels (\`Bucket: N (P buckets) are retained in \`text\`,
independent of the toggle's \`customdata\`.

## Usage

``` r
pd_BucketBar(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
  strOuterCol = NULL,
  strOuterLabel = NULL
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

- strOuterLabel:

  \`character\` Optional tooltip label for the parent tier (e.g.
  "Country" for the site chart). When supplied, two-tier tooltips name
  the parent above the group. \`NULL\` (default) omits the parent line.

## Value

A \`plotly\` htmlwidget.
