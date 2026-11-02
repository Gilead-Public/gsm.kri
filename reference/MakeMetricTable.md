# Generate a Summary data.frame for use in reports

\`r lifecycle::badge("stable")\`

Generate a summary table for a report by joining the provided results
data frame with the site-level metadata from dfGroups, and filter and
arrange the data based on provided conditions.

## Usage

``` r
MakeMetricTable(
  dfResults,
  dfGroups = NULL,
  strGroupLevel = c("Site", "Country", "Study"),
  strGroupDetailsParams = NULL,
  vFlags = c(-2, -1, 1, 2)
)
```

## Arguments

- dfResults:

  \`r gloss_param("dfResults")\` \`r gloss_extra("dfResults_filtered")\`

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- strGroupLevel:

  group level for the table

- strGroupDetailsParams:

  one or more parameters from dfGroups to be added as columns in the
  table

- vFlags:

  \`integer\` List of flag values to include in output table. Default:
  \`c(-2, -1, 1, 2)\`.

## Value

A data.frame containing the summary table

## Examples

``` r
# site-level report
MakeMetricTable(
  dfResults = gsm.core::reportingResults %>%
    dplyr::filter(.data$MetricID == "Analysis_kri0001") %>%
    FilterByLatestSnapshotDate(),
  dfGroups = gsm.core::reportingGroups
)
#>          StudyID GroupID         MetricID          Group SnapshotDate Enrolled
#> 1 AA-AA-000-0000  0X9490 Analysis_kri0001   0X9490 (Doe)   2025-04-01       13
#> 2 AA-AA-000-0000  0X6995 Analysis_kri0001  0X6995 (Deer)   2025-04-01        7
#> 3 AA-AA-000-0000  0X4747 Analysis_kri0001   0X4747 (Doe)   2025-04-01        4
#> 4 AA-AA-000-0000   0X700 Analysis_kri0001   0X700 (Deer)   2025-04-01        4
#> 5 AA-AA-000-0000  0X2861 Analysis_kri0001  0X2861 (Deer)   2025-04-01        4
#> 6 AA-AA-000-0000  0X8090 Analysis_kri0001   0X8090 (Doe)   2025-04-01        9
#> 7 AA-AA-000-0000  0X9252 Analysis_kri0001 0X9252 (Smith)   2025-04-01       11
#>   Numerator Denominator Metric Score Flag
#> 1        25         532   0.05 -1.56   -1
#> 2        13         306   0.04 -1.34   -1
#> 3         5         151   0.03 -1.17   -1
#> 4         0          50   0.00 -1.14   -1
#> 5         6         165   0.04 -1.14   -1
#> 6        16         318   0.05 -1.09   -1
#> 7        33         554   0.06 -1.00   -1
```
