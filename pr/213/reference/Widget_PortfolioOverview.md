# Portfolio Overview Widget

\`r lifecycle::badge("experimental")\`

A widget that renders a portfolio-level rollup table with one column per
KRI metric and one row per drill-down bucket (overall total plus
categories from study-level grouping params). Cells display numerator /
denominator / rate. Includes a filter bar (D2) and expandable drill-down
rows that reveal per-study contributions (D4).

For a working example see the \[Portfolio Overview
Report\](https://gilead-biostats.github.io/gsm.kri/examples/Example_PortfolioOverview.html).

## Usage

``` r
Widget_PortfolioOverview(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  vGroupParams = c("therapeutic_area", "protocol_indication", "phase", "status",
    "product"),
  vFilterParams = c("therapeutic_area", "phase", "status")
)
```

## Arguments

- dfResults:

  \`data.frame\` Cross-study KRI results.

- dfMetrics:

  \`data.frame\` Metadata about metrics/KRIs.

- dfGroups:

  \`data.frame\` Study-level group metadata in long format.

- strGroupLevel:

  \`character\` The group level. Default \`"Site"\`.

- vGroupParams:

  \`character\` Vector of \`Param\` values from \`dfGroups\` to use as
  drill-down categories.

- vFilterParams:

  \`character\` Vector of \`Param\` values exposed in the filter bar
  (D2). Defaults to therapeutic area, phase, status. StudyID is always
  available as a filter regardless of this argument.

## Value

An htmlwidget rendering the portfolio overview table.
