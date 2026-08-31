# Detect Consecutive Repeated Measures

\`r lifecycle::badge("experimental")\`

Annotates measurement records with consecutive-repeat information using
a rolling window of length \`nWindowLength\`. For each subject, records
are ordered chronologically and a window of length \*W\* is slid across
the ordered values; a window is a \*repeat window\* when all \*W\*
values in it are identical.

This is the shared workhorse behind \[Count_Duplicates()\] (metric
workflows, which sum the window indicators) and
\[Report_RecordDuplication()\] (drill-down report, which highlights the
underlying runs). It supports both wide-format data (e.g. vitals with a
single value column) and long-format data (e.g. labs where a measure
column identifies the test).

## Usage

``` r
Detect_ConsecutiveRepeats(
  df,
  strSubjectCol = "subjid",
  strDateCol = "vs_dt",
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL,
  nWindowLength = 3
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

- nWindowLength:

  \`numeric\` Rolling window length \*W\*. Must be a whole number \>= 2.
  Default: \`3\`.

## Value

A \`data.frame\` containing the input rows (filtered to the specified
measure if applicable, with \`NA\` values in \`strValueCol\` dropped),
ordered by subject and date, with five added integer columns: -
\`RunID\`: index of the maximal run of consecutive identical values the
record belongs to, numbered within subject. - \`RunLength\`: length of
that run. - \`IsRepeatRun\`: 1 when \`RunLength \>= nWindowLength\`,
i.e. the record is part of a run long enough to produce at least one
repeat window. Intended for report highlighting. -
\`IsEvaluableWindow\`: 1 when a full window of length \*W\* ends at this
record. The first \`W - 1\` records for each subject are 0. -
\`IsRepeatWindow\`: 1 when the window ending at this record contains
\*W\* identical values. Always 0 where \`IsEvaluableWindow\` is 0.

## Details

Windows are attributed to the record at which they \*end\*, which makes
the metric counts expressible as column sums:

\- numerator = \`sum(IsRepeatWindow)\` - denominator =
\`sum(IsEvaluableWindow)\` = \`total_measurements - (W - 1)\` per
subject

Subjects with fewer than \*W\* non-missing measurements contribute 0 to
both, so they are excluded from scoring rather than scored as a rate of
0.

Missing values are dropped \*before\* windowing, so two identical values
separated by a missing visit are treated as adjacent. Ties in
\`strDateCol\` are resolved by input order via a stable sort.

A maximal run of \`L\` identical consecutive values contributes \`max(0,
L - W + 1)\` repeat windows, which is the relationship the report relies
on to reconcile its highlighting with the metric.

## Examples

``` r
# Wide format (vitals) -- W = 3
df_vs <- data.frame(
  subjid = rep("S1", 6),
  vs_dt = as.Date("2024-01-01") + seq(0, 150, by = 30),
  weight = c(10, 10, 10, 1, 5, 6)
)
Detect_ConsecutiveRepeats(df_vs, strValueCol = "weight", nWindowLength = 3)
#>   subjid      vs_dt weight RunID RunLength IsRepeatRun IsEvaluableWindow
#> 1     S1 2024-01-01     10     1         3           1                 0
#> 2     S1 2024-01-31     10     1         3           1                 0
#> 3     S1 2024-03-01     10     1         3           1                 1
#> 4     S1 2024-03-31      1     2         1           0                 1
#> 5     S1 2024-04-30      5     3         1           0                 1
#> 6     S1 2024-05-30      6     4         1           0                 1
#>   IsRepeatWindow
#> 1              0
#> 2              0
#> 3              1
#> 4              0
#> 5              0
#> 6              0

# Long format (labs)
df_lb <- data.frame(
  subjid = rep("S1", 4),
  lb_dt = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
  lbtstnam = "ALT",
  rptresn = c(25, 25, 25, 35)
)
Detect_ConsecutiveRepeats(
  df_lb,
  strDateCol = "lb_dt", strValueCol = "rptresn",
  strMeasureCol = "lbtstnam", strMeasureVal = "ALT"
)
#>   subjid      lb_dt lbtstnam rptresn RunID RunLength IsRepeatRun
#> 1     S1 2024-01-01      ALT      25     1         3           1
#> 2     S1 2024-02-01      ALT      25     1         3           1
#> 3     S1 2024-03-01      ALT      25     1         3           1
#> 4     S1 2024-04-01      ALT      35     2         1           0
#>   IsEvaluableWindow IsRepeatWindow
#> 1                 0              0
#> 2                 0              0
#> 3                 1              1
#> 4                 1              0
```
