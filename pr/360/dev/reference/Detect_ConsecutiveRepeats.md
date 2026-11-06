# Detect consecutive repeated measurements

\`r lifecycle::badge("experimental")\`

Counts, per subject, the rolling windows of \`nWindowLength\`
consecutive measurements in which every value is identical. Missing
values are dropped before windows are formed. Records are ordered by
\`strDateCol\` within subject, then by \`strOrderCol\` to break
same-date ties. Records with a missing subject are dropped with a
warning.

## Usage

``` r
Detect_ConsecutiveRepeats(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strOrderCol = NULL,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
)
```

## Arguments

- df:

  \`data.frame\` One row per measurement record.

- strValueCol:

  \`character\` Column holding the measurement value.

- strSubjectCol:

  \`character\` Subject identifier column. Default \`"subjid"\`.

- strDateCol:

  \`character\` Date/ordering column. Default \`"vs_dt"\`. A \`Date\` or
  \`POSIXct\` column is used as is. A character (or factor) column must
  hold ISO dates (\`"YYYY-MM-DD"\`); it is converted to \`Date\` so
  that, for example, \`"2024-01-9"\` sorts before \`"2024-01-10"\`. Any
  other value is an error. Missing dates sort last within subject.

- strOrderCol:

  \`character\` Optional column(s) used, in order, to break ties on
  \`strDateCol\` (e.g. an intra-visit measurement time or \`"visit"\`).
  Default \`NULL\`, in which case tied records keep their input order.

- strMeasureCol:

  \`character\` Optional column identifying the measure, for long-format
  data. When supplied, \`df\` is filtered to \`strMeasureVal\`.

- strMeasureVal:

  \`character\` The single value of \`strMeasureCol\` to keep. Required
  when \`strMeasureCol\` is supplied.

- nWindowLength:

  \`numeric\` Window length; a whole number \>= 2. Default \`3\`.

## Value

A \`data.frame\` with one row per subject in \`df\` (after measure
filtering): the subject column, \`Numerator\` (count of all-equal
windows), and \`Denominator\` (\`n - nWindowLength + 1\`, floored at 0,
where \`n\` is the subject's non-missing measurement count). Subjects
with a \`Denominator\` of 0 contribute nothing to a rate.

## Examples

``` r
df <- data.frame(
  subjid = rep(c("A", "B"), each = 5),
  vs_dt = rep(as.Date("2024-01-01") + 0:4, 2),
  weight = c(10, 10, 5, 3, 10, 10, 10, 10, 10, 10)
)
Detect_ConsecutiveRepeats(df, "weight")
#>   subjid Numerator Denominator
#> 1      A         0           3
#> 2      B         3           3
```
