# Flag Duplicate Measurement Records

\`r lifecycle::badge("experimental")\`

Record-level helper that marks measurement records as duplicates when
their value matches any previously recorded value for the same subject.
Supports both wide-format data (e.g. vitals, where each measure is its
own column) and long-format data (e.g. labs, where the measure name is a
row value) via the optional \`strMeasureCol\`/\`strMeasureVal\`
arguments.

## Usage

``` r
Flag_Duplicates(
  df,
  strSubjectCol,
  strDateCol,
  strValueCol,
  strMeasureCol = NULL,
  strMeasureVal = NULL
)
```

## Arguments

- df:

  \`data.frame\` Input data containing at least the subject, date, and
  value columns.

- strSubjectCol:

  \`character\` Column identifying the subject (e.g. \`"subjid"\`).

- strDateCol:

  \`character\` Column used to order records chronologically (e.g.
  \`"vs_dt"\`).

- strValueCol:

  \`character\` Column containing the measurement value to check for
  duplicates (e.g. \`"weight"\`, \`"rptresn"\`).

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
