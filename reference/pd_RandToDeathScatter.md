# Randomization-to-event scatter

\`r lifecycle::badge("experimental")\`

Scatter of every enrolled subject from \[pd_Classify()\]: x =
\`x_anchor\` (death day for deaths; the window boundary for "alive at
window"; follow-up for "alive prior"; discontinuation day for
discontinuations), y = \`follow_up\` (days from randomization to
snapshot). Colored by category; each category (including the two death
categories) is a separate legend entry (SI-1 design decision: no grouped
"Death within \`nWindowDays\` days" heading). Pass
\`vXRange\`/\`vYRange\` (computed study-wide by the report) to fix a
shared range across the study/country/site views (AXIS-1). Each point's
\`customdata\` packs \`\[hover, country, invid\]\` so the report can
filter points client-side.

## Usage

``` r
pd_RandToDeathScatter(
  dfClassified,
  nWindowDays = 90,
  vXRange = NULL,
  vYRange = NULL
)
```

## Arguments

- dfClassified:

  \`data.frame\` Output of \[pd_Classify()\]. May already carry the
  \`hover\`/\`pd_customdata\` columns built by \[pd_ScatterData()\] — in
  that case the per-point build is skipped (idempotent).

- nWindowDays:

  \`numeric\` Window in days (color/legend vocabulary). Default 90.

- vXRange:

  \`numeric(2)\` Optional fixed x-axis range. \`NULL\` autoranges.

- vYRange:

  \`numeric(2)\` Optional fixed y-axis range. \`NULL\` autoranges.

## Value

A \`plotly\` htmlwidget.
