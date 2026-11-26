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
#>           StudyID GroupID         MetricID          Group SnapshotDate Enrolled
#> 1  AA-AA-000-0000  0X2025 Analysis_kri0001 0X2025 (Smith)   2025-04-01        5
#> 2  AA-AA-000-0000  0X7303 Analysis_kri0001   0X7303 (Doe)   2025-04-01       11
#> 3  AA-AA-000-0000   0X464 Analysis_kri0001  0X464 (Smith)   2025-04-01        6
#> 4  AA-AA-000-0000  0X5940 Analysis_kri0001 0X5940 (Smith)   2025-04-01        8
#> 5  AA-AA-000-0000  0X6315 Analysis_kri0001   0X6315 (Doe)   2025-04-01        3
#> 6  AA-AA-000-0000  0X1755 Analysis_kri0001   0X1755 (Doe)   2025-04-01        2
#> 7  AA-AA-000-0000  0X4769 Analysis_kri0001 0X4769 (Smith)   2025-04-01        4
#> 8  AA-AA-000-0000  0X3235 Analysis_kri0001 0X3235 (Smith)   2025-04-01        6
#> 9  AA-AA-000-0000   0X799 Analysis_kri0001   0X799 (Deer)   2025-04-01        2
#> 10 AA-AA-000-0000  0X7772 Analysis_kri0001   0X7772 (Doe)   2025-04-01        7
#> 11 AA-AA-000-0000  0X9705 Analysis_kri0001  0X9705 (Deer)   2025-04-01        2
#> 12 AA-AA-000-0000  0X4290 Analysis_kri0001 0X4290 (Smith)   2025-04-01        8
#>    Numerator Denominator Metric Score Flag
#> 1         13          35   0.37  4.13    2
#> 2         17         340   0.05 -1.40   -1
#> 3          9         201   0.04 -1.25   -1
#> 4         18         338   0.05 -1.25   -1
#> 5          1          60   0.02 -1.21   -1
#> 6          3          96   0.03 -1.18   -1
#> 7          3          88   0.03 -1.07   -1
#> 8         12         229   0.05 -1.06   -1
#> 9          1          50   0.02 -1.05   -1
#> 10        22         370   0.06 -1.02   -1
#> 11         1          48   0.02 -1.01   -1
#> 12        21         354   0.06 -1.00   -1
```
