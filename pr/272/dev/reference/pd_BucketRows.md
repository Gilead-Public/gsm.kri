# Long-format premature-death bucket rows for gsm.viz \`bars\`

Adapts \[pd_BucketCounts()\] to one row per (group, category) with
within-group \`pct\`, plus stable \`OuterGroupID\` / \`Level\` keys for
the country-\>site click-filter drilldown. \`.drop = FALSE\` zero-count
cells are preserved.

## Usage

``` r
pd_BucketRows(
  dfClassified,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strOuterCol = NULL
)
```

## Arguments

- dfClassified:

  \`data.frame\` Output of \[pd_Classify()\].

- nWindowDays:

  \`numeric\` Window in days.

- strGroupCol:

  \`character\` Column rendered on the category axis.

- strOuterCol:

  \`character\` Optional parent column carried as \`OuterGroupID\` (the
  site chart passes \`"country"\` so its rows drive the country-\>site
  click-filter narrowing and the click payload). Default \`NULL\`.

## Value

\`data.frame\` with \`GroupID\`, \`OuterGroupID\`, \`Category\`, \`n\`,
\`pct\`, \`Level\`.
