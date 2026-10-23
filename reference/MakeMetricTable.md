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
#> 1  AA-AA-000-0000  0X1748 Analysis_kri0001   0X1748 (Doe)   2025-04-01        7
#> 2  AA-AA-000-0000  0X7838 Analysis_kri0001  0X7838 (Deer)   2025-04-01        3
#> 3  AA-AA-000-0000  0X1544 Analysis_kri0001   0X1544 (Doe)   2025-04-01        2
#> 4  AA-AA-000-0000  0X9346 Analysis_kri0001   0X9346 (Doe)   2025-04-01       11
#> 5  AA-AA-000-0000  0X3081 Analysis_kri0001   0X3081 (Doe)   2025-04-01       11
#> 6  AA-AA-000-0000  0X5611 Analysis_kri0001   0X5611 (Doe)   2025-04-01        6
#> 7  AA-AA-000-0000  0X2373 Analysis_kri0001   0X2373 (Doe)   2025-04-01        5
#> 8  AA-AA-000-0000   0X958 Analysis_kri0001   0X958 (Deer)   2025-04-01       11
#> 9  AA-AA-000-0000  0X8351 Analysis_kri0001  0X8351 (Deer)   2025-04-01        9
#> 10 AA-AA-000-0000  0X8764 Analysis_kri0001 0X8764 (Smith)   2025-04-01        4
#> 11 AA-AA-000-0000  0X5425 Analysis_kri0001 0X5425 (Smith)   2025-04-01        2
#> 12 AA-AA-000-0000  0X4671 Analysis_kri0001 0X4671 (Smith)   2025-04-01        2
#> 13 AA-AA-000-0000  0X8768 Analysis_kri0001  0X8768 (Deer)   2025-04-01        7
#>    Numerator Denominator Metric Score Flag
#> 1         26         125   0.21  3.22    2
#> 2          8          32   0.25  2.19    1
#> 3          1          79   0.01 -1.58   -1
#> 4         35         570   0.06 -1.47   -1
#> 5         26         435   0.06 -1.37   -1
#> 6          5         126   0.04 -1.27   -1
#> 7          7         155   0.05 -1.25   -1
#> 8         32         497   0.06 -1.22   -1
#> 9         28         440   0.06 -1.18   -1
#> 10         8         162   0.05 -1.15   -1
#> 11         2          61   0.03 -1.02   -1
#> 12         1          43   0.02 -1.00   -1
#> 13         5         107   0.05 -1.00   -1
```
