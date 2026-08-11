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
#> 1  AA-AA-000-0000  0X9322 Analysis_kri0001 0X9322 (Smith)   2025-04-01        4
#> 2  AA-AA-000-0000  0X2532 Analysis_kri0001   0X2532 (Doe)   2025-04-01        5
#> 3  AA-AA-000-0000  0X9981 Analysis_kri0001  0X9981 (Deer)   2025-04-01        3
#> 4  AA-AA-000-0000  0X7983 Analysis_kri0001 0X7983 (Smith)   2025-04-01        7
#> 5  AA-AA-000-0000  0X1760 Analysis_kri0001   0X1760 (Doe)   2025-04-01        5
#> 6  AA-AA-000-0000  0X4555 Analysis_kri0001 0X4555 (Smith)   2025-04-01        2
#> 7  AA-AA-000-0000  0X2434 Analysis_kri0001  0X2434 (Deer)   2025-04-01        5
#> 8  AA-AA-000-0000  0X9580 Analysis_kri0001  0X9580 (Deer)   2025-04-01        8
#> 9  AA-AA-000-0000  0X4904 Analysis_kri0001   0X4904 (Doe)   2025-04-01       10
#> 10 AA-AA-000-0000  0X9360 Analysis_kri0001 0X9360 (Smith)   2025-04-01       11
#> 11 AA-AA-000-0000  0X5367 Analysis_kri0001  0X5367 (Deer)   2025-04-01        6
#> 12 AA-AA-000-0000  0X1487 Analysis_kri0001  0X1487 (Deer)   2025-04-01        9
#> 13 AA-AA-000-0000  0X9346 Analysis_kri0001   0X9346 (Doe)   2025-04-01        8
#> 14 AA-AA-000-0000  0X2446 Analysis_kri0001   0X2446 (Doe)   2025-04-01        2
#> 15 AA-AA-000-0000  0X3087 Analysis_kri0001 0X3087 (Smith)   2025-04-01        2
#>    Numerator Denominator Metric Score Flag
#> 1         11          53   0.21  2.23    1
#> 2         12         285   0.04 -1.98   -1
#> 3          0          60   0.00 -1.74   -1
#> 4         15         281   0.05 -1.48   -1
#> 5          6         146   0.04 -1.44   -1
#> 6          0          39   0.00 -1.40   -1
#> 7         10         199   0.05 -1.36   -1
#> 8         22         361   0.06 -1.31   -1
#> 9         19         317   0.06 -1.27   -1
#> 10        39         573   0.07 -1.21   -1
#> 11        10         187   0.05 -1.20   -1
#> 12        16         266   0.06 -1.15   -1
#> 13        28         423   0.07 -1.14   -1
#> 14         1          43   0.02 -1.08   -1
#> 15         1          41   0.02 -1.04   -1
```
