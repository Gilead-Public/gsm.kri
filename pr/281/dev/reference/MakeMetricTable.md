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
#> 1  AA-AA-000-0000  0X8743 Analysis_kri0001 0X8743 (Smith)   2025-04-01        3
#> 2  AA-AA-000-0000  0X7497 Analysis_kri0001 0X7497 (Smith)   2025-04-01        3
#> 3  AA-AA-000-0000  0X2413 Analysis_kri0001 0X2413 (Smith)   2025-04-01        9
#> 4  AA-AA-000-0000  0X4264 Analysis_kri0001  0X4264 (Deer)   2025-04-01       10
#> 5  AA-AA-000-0000  0X8788 Analysis_kri0001  0X8788 (Deer)   2025-04-01        5
#> 6  AA-AA-000-0000  0X8318 Analysis_kri0001  0X8318 (Deer)   2025-04-01        2
#> 7  AA-AA-000-0000  0X4874 Analysis_kri0001   0X4874 (Doe)   2025-04-01        9
#> 8  AA-AA-000-0000  0X8354 Analysis_kri0001  0X8354 (Deer)   2025-04-01        6
#> 9  AA-AA-000-0000  0X9360 Analysis_kri0001 0X9360 (Smith)   2025-04-01       10
#> 10 AA-AA-000-0000  0X9346 Analysis_kri0001   0X9346 (Doe)   2025-04-01        3
#> 11 AA-AA-000-0000  0X8351 Analysis_kri0001  0X8351 (Deer)   2025-04-01        7
#> 12 AA-AA-000-0000  0X6603 Analysis_kri0001 0X6603 (Smith)   2025-04-01        9
#> 13 AA-AA-000-0000   0X759 Analysis_kri0001  0X759 (Smith)   2025-04-01       10
#> 14 AA-AA-000-0000  0X3676 Analysis_kri0001 0X3676 (Smith)   2025-04-01        9
#> 15 AA-AA-000-0000  0X8786 Analysis_kri0001  0X8786 (Deer)   2025-04-01       15
#> 16 AA-AA-000-0000   0X539 Analysis_kri0001   0X539 (Deer)   2025-04-01        3
#> 17 AA-AA-000-0000  0X6666 Analysis_kri0001   0X6666 (Doe)   2025-04-01        3
#> 18 AA-AA-000-0000  0X1084 Analysis_kri0001  0X1084 (Deer)   2025-04-01        2
#> 19 AA-AA-000-0000  0X8964 Analysis_kri0001 0X8964 (Smith)   2025-04-01        2
#> 20 AA-AA-000-0000  0X7011 Analysis_kri0001  0X7011 (Deer)   2025-04-01        7
#> 21 AA-AA-000-0000  0X9051 Analysis_kri0001 0X9051 (Smith)   2025-04-01        2
#>    Numerator Denominator Metric Score Flag
#> 1          8          30   0.27  2.69    1
#> 2         15          82   0.18  2.39    1
#> 3         25         165   0.15  2.30    1
#> 4         43         339   0.13  2.07    1
#> 5         11         247   0.04 -1.73   -1
#> 6          0          46   0.00 -1.56   -1
#> 7         22         392   0.06 -1.55   -1
#> 8         17         311   0.05 -1.45   -1
#> 9         26         429   0.06 -1.38   -1
#> 10         9         181   0.05 -1.29   -1
#> 11        16         278   0.06 -1.24   -1
#> 12        32         490   0.07 -1.19   -1
#> 13        22         353   0.06 -1.16   -1
#> 14        16         269   0.06 -1.14   -1
#> 15        44         639   0.07 -1.11   -1
#> 16         2          61   0.03 -1.11   -1
#> 17         1          43   0.02 -1.10   -1
#> 18         3          76   0.04 -1.08   -1
#> 19         1          42   0.02 -1.07   -1
#> 20        17         275   0.06 -1.05   -1
#> 21         1          39   0.03 -1.00   -1
```
