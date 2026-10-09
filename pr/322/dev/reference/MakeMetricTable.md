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
#> 1  AA-AA-000-0000  0X9040 Analysis_kri0001  0X9040 (Deer)   2025-04-01        5
#> 2  AA-AA-000-0000  0X4086 Analysis_kri0001 0X4086 (Smith)   2025-04-01        4
#> 3  AA-AA-000-0000  0X7317 Analysis_kri0001   0X7317 (Doe)   2025-04-01        5
#> 4  AA-AA-000-0000  0X5408 Analysis_kri0001  0X5408 (Deer)   2025-04-01        8
#> 5  AA-AA-000-0000  0X3090 Analysis_kri0001 0X3090 (Smith)   2025-04-01        7
#> 6  AA-AA-000-0000  0X5577 Analysis_kri0001  0X5577 (Deer)   2025-04-01        3
#> 7  AA-AA-000-0000  0X3351 Analysis_kri0001 0X3351 (Smith)   2025-04-01        3
#> 8  AA-AA-000-0000  0X8368 Analysis_kri0001  0X8368 (Deer)   2025-04-01        3
#> 9  AA-AA-000-0000  0X5737 Analysis_kri0001   0X5737 (Doe)   2025-04-01        7
#> 10 AA-AA-000-0000  0X7238 Analysis_kri0001   0X7238 (Doe)   2025-04-01        3
#> 11 AA-AA-000-0000  0X9246 Analysis_kri0001  0X9246 (Deer)   2025-04-01        7
#> 12 AA-AA-000-0000  0X3289 Analysis_kri0001  0X3289 (Deer)   2025-04-01        5
#> 13 AA-AA-000-0000  0X1257 Analysis_kri0001   0X1257 (Doe)   2025-04-01        6
#> 14 AA-AA-000-0000  0X2339 Analysis_kri0001 0X2339 (Smith)   2025-04-01        3
#> 15 AA-AA-000-0000  0X5033 Analysis_kri0001 0X5033 (Smith)   2025-04-01        5
#>    Numerator Denominator Metric Score Flag
#> 1         13          40   0.32  3.48    2
#> 2         11          32   0.34  3.35    2
#> 3         11          39   0.28  2.82    1
#> 4         11         275   0.04 -1.75   -1
#> 5         18         355   0.05 -1.53   -1
#> 6          0          57   0.00 -1.49   -1
#> 7          4         129   0.03 -1.43   -1
#> 8          0          43   0.00 -1.30   -1
#> 9         10         211   0.05 -1.29   -1
#> 10         2          73   0.03 -1.15   -1
#> 11         9         183   0.05 -1.14   -1
#> 12        12         224   0.05 -1.11   -1
#> 13        18         300   0.06 -1.03   -1
#> 14         6         129   0.05 -1.03   -1
#> 15        11         202   0.05 -1.03   -1
```
