# Detect consecutive repeated measurements

\`r lifecycle::badge("experimental")\`

Counts, per subject, the rolling windows of \`nWindowLength\`
consecutive measurements in which every value is identical. The result
feeds \[gsm.core::Input_Rate()\] (with \`strNumeratorMethod = "Sum"\`
and \`strDenominatorMethod = "Sum"\`) to produce the repeat-measure KRIs
(\`kri0020a\`-\`f\`, \`cou0020a\`-\`f\`).

Missing values are dropped before windows are formed (a missed visit is
excluded, not treated as a non-match). Records are ordered by
\`strDateCol\` within subject; ties keep their input order, so pass data
pre-sorted by any intra-visit key (\`Mapped_VS\` is sorted by \`vs_dt\`
then \`visit\`).

## Usage

``` r
Detect_ConsecutiveRepeats(
  df,
  strValueCol,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
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

  \`character\` Date/ordering column. Default \`"vs_dt"\`.

- strMeasureCol:

  \`character\` Optional column identifying the measure, for long-format
  data. When supplied, \`df\` is filtered to \`strMeasureVal\`.

- strMeasureVal:

  \`character\` Value of \`strMeasureCol\` to keep. Required when
  \`strMeasureCol\` is supplied.

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
