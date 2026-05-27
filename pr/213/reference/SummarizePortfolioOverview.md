# Summarize Portfolio Overview

\`r lifecycle::badge("experimental")\`

Aggregates KRI results across studies into a portfolio-level rollup.
Returns a long-format summary with one row per (Group, MetricID) cell,
where Group is either the portfolio total or a value of a study-level
grouping parameter (e.g. therapeutic area, phase, status, product,
protocol indication). Each cell contains numerator, denominator, and
rate values rolled up from the latest snapshot.

Per the design spec for \#212, this helper: - includes all metrics in
\`dfResults\` (no filtering). - sorts metrics by \`MetricID\`
ascending. - includes all studies in \`dfResults\`. - uses the latest
\`SnapshotDate\` only when multiple snapshots are present.

## Usage

``` r
SummarizePortfolioOverview(
  dfResults,
  dfGroups = NULL,
  strGroupLevel = "Site",
  vGroupParams = c("therapeutic_area", "protocol_indication", "phase", "status",
    "product")
)
```

## Arguments

- dfResults:

  \`data.frame\` Cross-study KRI results. Must include \`StudyID\`,
  \`MetricID\`, \`GroupLevel\`, \`Numerator\`, \`Denominator\`. May
  include \`SnapshotDate\`; if so, only the latest snapshot is retained.

- dfGroups:

  \`data.frame\` Study-level group metadata in long format with columns
  \`StudyID\`, \`GroupLevel\`, \`Param\`, \`Value\`. Used to look up
  per-study attributes for the drill-down rows.

- strGroupLevel:

  \`character\` The \`GroupLevel\` value in \`dfResults\` to summarize
  across. Default \`"Site"\`.

- vGroupParams:

  \`character\` Vector of study-level \`Param\` values from \`dfGroups\`
  to use as drill-down categories. Defaults to the five
  \`reporting.groups\` study-level params used in \#212:
  \`therapeutic_area\`, \`protocol_indication\`, \`phase\`, \`status\`,
  \`product\`.

## Value

\`data.frame\` long-format summary with columns: - \`GroupCategory\`:
name of the grouping (e.g. \`"Total"\`, \`"therapeutic_area"\`). -
\`GroupValue\`: the specific bucket value (e.g. \`"Total"\`,
\`"Oncology"\`). - \`MetricID\`: metric identifier. - \`Numerator\`:
summed numerator across studies in the bucket. - \`Denominator\`: summed
denominator across studies in the bucket. - \`Rate\`: \`Numerator /
Denominator\` (NA when denominator is 0). - \`NumStudies\`: number of
distinct studies contributing to the bucket.

## Examples

``` r
if (FALSE) { # \dontrun{
# See pkgdown/menus/examples/Example_PortfolioOverview.Rmd
} # }
```
