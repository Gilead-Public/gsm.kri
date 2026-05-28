# Flag Duplicate Records

\`r lifecycle::badge("experimental")\`

Flags records as duplicates when their value matches any previous value
for the same subject. The first record for each subject is never flagged
as a duplicate. Supports both wide-format data (e.g., vitals with a
single value column) and long-format data (e.g., labs where a measure
column identifies the test).

## Usage

``` r
Flag_Duplicates(
  df,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL
)
```

## Arguments

- df:

  \`data.frame\` Input data with one row per measurement record.

- strSubjectCol:

  \`character\` Column name for subject identifier. Default:
  \`"subjid"\`.

- strDateCol:

  \`character\` Column name for date/ordering. Default: \`"vs_dt"\`.

- strValueCol:

  \`character\` Column name for the measurement value. Required.

- strMeasureCol:

  \`character\` Optional column name identifying the measure/test (for
  long-format data like labs). When provided, data is filtered to
  \`strMeasureVal\`.

- strMeasureVal:

  \`character\` Value to filter on in \`strMeasureCol\`. Required if
  \`strMeasureCol\` is provided.

## Value

A \`data.frame\` containing the input rows (filtered to the specified
measure if applicable), with two added integer columns: -
\`is_duplicate\` (1 = duplicate, 0 = not): a record is duplicate if its
value matches any prior value for the same subject. - \`is_source\` (1 =
source of a duplicate, 0 = not): a record is the source if it was the
earliest prior record whose value was later copied by a duplicate
record. Rows with NA values in \`strValueCol\` are excluded.

## Details

The function: 1. Optionally filters to a specific measure (long-format
support) 2. Removes rows where the value column is NA 3. Orders records
by subject and date 4. For each subject, marks a record as duplicate (1)
if its value exactly matches any previously recorded value for that
subject. The first record is always 0.

## Examples

``` r
# Wide format (vitals)
df_vs <- data.frame(
  subjid = c("S1", "S1", "S1", "S2", "S2"),
  vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-01-01", "2024-02-01")),
  weight = c(75.0, 75.0, 76.0, 80.0, 80.0)
)
Flag_Duplicates(df_vs, strValueCol = "weight")
#>   subjid      vs_dt weight is_duplicate is_source
#> 1     S1 2024-01-01     75            0         1
#> 2     S1 2024-02-01     75            1         0
#> 3     S1 2024-03-01     76            0         0
#> 4     S2 2024-01-01     80            0         1
#> 5     S2 2024-02-01     80            1         0

# Long format (labs)
df_lb <- data.frame(
  subjid = c("S1", "S1", "S1", "S1"),
  lb_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-01-01", "2024-02-01")),
  lbtstnam = c("ALT", "ALT", "AST", "AST"),
  rptresn = c(25, 25, 30, 35)
)
Flag_Duplicates(df_lb, strDateCol = "lb_dt", strValueCol = "rptresn",
                strMeasureCol = "lbtstnam", strMeasureVal = "ALT")
#>   subjid      lb_dt lbtstnam rptresn is_duplicate is_source
#> 1     S1 2024-01-01      ALT      25            0         1
#> 2     S1 2024-02-01      ALT      25            1         0
```
