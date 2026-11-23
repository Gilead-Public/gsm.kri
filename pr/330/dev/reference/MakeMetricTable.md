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
#> 1  AA-AA-000-0000  0X9248 Analysis_kri0001 0X9248 (Smith)   2025-04-01        5
#> 2  AA-AA-000-0000  0X4290 Analysis_kri0001 0X4290 (Smith)   2025-04-01        9
#> 3  AA-AA-000-0000  0X4889 Analysis_kri0001 0X4889 (Smith)   2025-04-01        5
#> 4  AA-AA-000-0000  0X5069 Analysis_kri0001 0X5069 (Smith)   2025-04-01        5
#> 5  AA-AA-000-0000  0X5940 Analysis_kri0001 0X5940 (Smith)   2025-04-01        7
#> 6  AA-AA-000-0000  0X4166 Analysis_kri0001   0X4166 (Doe)   2025-04-01        3
#> 7  AA-AA-000-0000  0X1755 Analysis_kri0001   0X1755 (Doe)   2025-04-01        2
#> 8  AA-AA-000-0000  0X8374 Analysis_kri0001  0X8374 (Deer)   2025-04-01       10
#> 9  AA-AA-000-0000  0X7772 Analysis_kri0001   0X7772 (Doe)   2025-04-01        9
#> 10 AA-AA-000-0000  0X3059 Analysis_kri0001   0X3059 (Doe)   2025-04-01        8
#> 11 AA-AA-000-0000  0X9375 Analysis_kri0001 0X9375 (Smith)   2025-04-01        7
#> 12 AA-AA-000-0000   0X239 Analysis_kri0001   0X239 (Deer)   2025-04-01       11
#> 13 AA-AA-000-0000  0X2775 Analysis_kri0001   0X2775 (Doe)   2025-04-01       11
#> 14 AA-AA-000-0000   0X451 Analysis_kri0001    0X451 (Doe)   2025-04-01        9
#> 15 AA-AA-000-0000  0X5343 Analysis_kri0001   0X5343 (Doe)   2025-04-01        9
#> 16 AA-AA-000-0000  0X3040 Analysis_kri0001  0X3040 (Deer)   2025-04-01        2
#> 17 AA-AA-000-0000   0X126 Analysis_kri0001    0X126 (Doe)   2025-04-01        3
#>    Numerator Denominator Metric Score Flag
#> 1         14          56   0.25  3.85    2
#> 2         15         351   0.04 -2.20   -2
#> 3         12          57   0.21  2.98    1
#> 4         10          56   0.18  2.22    1
#> 5         15         311   0.05 -1.77   -1
#> 6          0          47   0.00 -1.70   -1
#> 7          3          96   0.03 -1.49   -1
#> 8         15         283   0.05 -1.44   -1
#> 9         24         402   0.06 -1.31   -1
#> 10        12         223   0.05 -1.25   -1
#> 11        17         295   0.06 -1.23   -1
#> 12        23         379   0.06 -1.22   -1
#> 13        30         476   0.06 -1.21   -1
#> 14        16         276   0.06 -1.18   -1
#> 15        21         345   0.06 -1.15   -1
#> 16         1          42   0.02 -1.13   -1
#> 17         8         151   0.05 -1.06   -1
```
