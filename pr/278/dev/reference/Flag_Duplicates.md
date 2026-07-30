# Flag Duplicate Measurement Records

\`r lifecycle::badge("experimental")\`

Record-level helper that marks measurement records as duplicates when
their value matches any previously recorded value for the same subject.
Supports both wide-format data (e.g. vitals, where each measure is its
own column) and long-format data (e.g. labs, where the measure name is a
row value).

## Usage

``` r
Flag_Duplicates(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strMeasureCol = NULL,
  strMeasureVal = NULL
)
```

## Arguments

- df:

  \`data.frame\` Input data containing at least the subject, date, and
  value columns.

- strValueCol:

  \`character\` Column containing the measurement value to check for
  duplicates (e.g. \`"weight"\`, \`"rptresn"\`).

- strSubjectCol:

  \`character\` Column identifying the subject (e.g. \`"subjid"\`).

- strDateCol:

  \`character\` Column used to order records chronologically (e.g.
  \`"vs_dt"\`).

- strMeasureCol:

  \`character\` Optional column containing the measure name, used to
  filter to a specific test in long-format data (e.g. \`"lbtstnam"\`).

- strMeasureVal:

  \`character\` Optional value in \`strMeasureCol\` to retain (e.g.
  \`"ALT (SGPT)"\`). Required when \`strMeasureCol\` is provided.

## Value

A filtered \`data.frame\` with an added \`is_duplicate\` logical column.
Rows with \`NA\` in \`strValueCol\` are dropped, as are rows that do not
match \`strMeasureVal\` when \`strMeasureCol\` is specified.

## Examples

``` r
# Wide-format (vitals): each measure is its own column.
dfVitals <- data.frame(
  subjid = c("001", "001", "001"),
  vs_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
  weight = c(72.3, 72.3, 73.1)
)
Flag_Duplicates(df = dfVitals, strValueCol = "weight")
#>   subjid      vs_dt weight is_duplicate
#> 1    001 2024-01-01   72.3        FALSE
#> 2    001 2024-02-01   72.3         TRUE
#> 3    001 2024-03-01   73.1        FALSE

# Long-format (labs): measure name is a row value.
dfLabs <- data.frame(
  subjid = c("001", "001", "001", "001"),
  lb_dt = as.Date(c("2024-01-01", "2024-01-01", "2024-02-01", "2024-02-01")),
  lbtstnam = c("ALT (SGPT)", "AST (SGOT)", "ALT (SGPT)", "AST (SGOT)"),
  rptresn = c(20, 20, 20, 30)
)
Flag_Duplicates(
  df = dfLabs,
  strValueCol = "rptresn",
  strDateCol = "lb_dt",
  strMeasureCol = "lbtstnam",
  strMeasureVal = "ALT (SGPT)"
)
#>   subjid      lb_dt   lbtstnam rptresn is_duplicate
#> 1    001 2024-01-01 ALT (SGPT)      20        FALSE
#> 2    001 2024-02-01 ALT (SGPT)      20         TRUE
```
