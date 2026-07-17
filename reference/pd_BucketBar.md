# Premature-death bucket bar chart

\`r lifecycle::badge("experimental")\`

Stacked bar of \[pd_Classify()\] category counts per group. Each point's
\`customdata\` carries \`\[count, pct\]\` so the report can toggle
counts/percent client-side. On-bar \`text\` shows the bare count (blank
for empty buckets). Each of the five categories is its own legend entry;
traces stack bottom-to-top in \`pd_DisplayOrder()\` order (best outcome
at the base, death-within-30 on top).

## Usage

``` r
pd_BucketBar(
  dfClassified,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
  strOuterCol = NULL,
  strOuterLabel = NULL,
  bRangeSlider = FALSE
)
```

## Arguments

- dfClassified:

  \`data.frame\` Output of \[pd_Classify()\].

- nWindowDays:

  \`numeric\` Window in days (legend/color vocabulary). Default 90.

- strGroupCol:

  \`character\` Column to group by. Default "studyid".

- strGroupLabel:

  \`character\` Axis label. Default "Group".

- strOuterCol:

  \`character\` Optional parent column for a two-tier x-axis.

- strOuterLabel:

  \`character\` Optional tooltip label for the parent tier.

- bRangeSlider:

  \`logical\` Add a scroll-only x range slider. Default FALSE.

## Value

A \`plotly\` htmlwidget.
