# Mark measurements inside consecutive repeat windows

\`r lifecycle::badge("experimental")\`

Returns every non-missing measurement in the order
\[Detect_ConsecutiveRepeats()\] evaluates it, marked when it sits inside
a rolling window of \`nWindowLength\` identical consecutive values. Both
functions share the same ordering and window logic, so summing
\`window_start\` per subject reproduces the \`Numerator\` of
\[Detect_ConsecutiveRepeats()\].

## Usage

``` r
Mark_ConsecutiveRepeats(
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

  \`character\` Date/ordering column. Default \`"vs_dt"\`.

- strOrderCol:

  \`character\` Optional column(s) used, in order, to break ties on
  \`strDateCol\` (e.g. an intra-visit measurement time or \`"visit"\`).
  Default \`NULL\`, in which case tied records keep their input order.

- strMeasureCol:

  \`character\` Optional column identifying the measure, for long-format
  data. When supplied, \`df\` is filtered to \`strMeasureVal\`.

- strMeasureVal:

  \`character\` Value of \`strMeasureCol\` to keep. Required when
  \`strMeasureCol\` is supplied.

- nWindowLength:

  \`numeric\` Window length; a whole number \>= 2. Default \`3\`.

## Value

\`df\` without rows whose value is missing, ordered by subject, then
\`strDateCol\`, then \`strOrderCol\`, with three columns added: \*
\`seq\`: position of the measurement within its subject. \*
\`in_repeat_window\`: \`TRUE\` when the measurement belongs to at least
one all-identical window. \* \`window_start\`: \`TRUE\` when the window
starting at this measurement is all-identical. Its per-subject sum is
the repeat-window count.

## Examples

``` r
df <- data.frame(
  subjid = rep(c("A", "B"), each = 5),
  vs_dt = rep(as.Date("2024-01-01") + 0:4, 2),
  weight = c(10, 10, 5, 3, 10, 10, 10, 10, 10, 10)
)
Mark_ConsecutiveRepeats(df, "weight")
#>    subjid      vs_dt weight seq in_repeat_window window_start
#> 1       A 2024-01-01     10   1            FALSE        FALSE
#> 2       A 2024-01-02     10   2            FALSE        FALSE
#> 3       A 2024-01-03      5   3            FALSE        FALSE
#> 4       A 2024-01-04      3   4            FALSE        FALSE
#> 5       A 2024-01-05     10   5            FALSE        FALSE
#> 6       B 2024-01-01     10   1             TRUE         TRUE
#> 7       B 2024-01-02     10   2             TRUE         TRUE
#> 8       B 2024-01-03     10   3             TRUE         TRUE
#> 9       B 2024-01-04     10   4             TRUE        FALSE
#> 10      B 2024-01-05     10   5             TRUE        FALSE
```
