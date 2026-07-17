# Classify enrolled subjects into premature-death categories

\`r lifecycle::badge("experimental")\`

Single source of truth for the five premature-death categories. Every
enrolled subject in \`dfSubjects\` is assigned exactly one \`Category\`
by precedence (first match wins): death \`\<=30d\` -\> death \`31-Wd\`
-\> study discontinuation within the window -\> alive at the window
(\`follow_up \>= nWindowDays\`, which includes a death after the window
– it survived the window) -\> alive prior to the window. \`discont_dy\`
is \`discontinuation_date - rgmn_dt\`, mirroring how \`death_dy\` is
derived, so the whole report shares one day-zero (randomization).

## Usage

``` r
pd_Classify(
  dfSubjects,
  dfDeath,
  dfStudComp = NULL,
  dfRand = NULL,
  nWindowDays = 90,
  dSnapshotDate = Sys.Date(),
  strDiscontDateCol = "mincreated_dts",
  strDeathReason = "Death"
)
```

## Arguments

- dfSubjects:

  \`data.frame\` Enrolled subjects: \`subjid\` (+ \`studyid\` /
  \`country\` / \`invid\` when present). Needs \`rgmn_dt\`, or supply
  \`dfRand\`.

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\` and \`death_dy\`.

- dfStudComp:

  \`data.frame\` (optional) Study-completion data with \`subjid\`,
  \`compyn\`, \`compreas\`, and \`strDiscontDateCol\`. \`NULL\`
  (default) yields no discontinuation category.

- dfRand:

  \`data.frame\` (optional) Randomization data with \`subjid\` and
  \`rgmn_dt\`, used when \`dfSubjects\` lacks \`rgmn_dt\`.

- nWindowDays:

  \`numeric\` Window in days. Default 90.

- dSnapshotDate:

  \`Date\` Reporting snapshot (drives \`follow_up\`). Default
  \`Sys.Date()\`.

- strDiscontDateCol:

  \`character\` Column in \`dfStudComp\` used as the discontinuation
  date. Default \`"mincreated_dts"\` (a proxy; repoint to a true
  discontinuation/end-of-study date when one is mapped).

- strDeathReason:

  \`character\` \`compreas\` value meaning death (excluded from the
  discontinuation category). Default \`"Death"\`.

## Value

A \`tibble\`: \`subjid\`, \`studyid\`, \`country\`, \`invid\`,
\`Category\` (factor with the \[pd_CategoryLevels()\] levels),
\`death_dy\`, \`discont_dy\`, \`follow_up\`, \`x_anchor\`.
