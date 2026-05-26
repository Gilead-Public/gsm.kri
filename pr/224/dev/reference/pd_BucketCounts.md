# Premature-death bucket counts

\`r lifecycle::badge("experimental")\`

Categorizes every enrolled subject into a premature-death bucket
(\`\<=30d\`, \`31-Wd\`, or \`Alive at Wd\`, where \`W\` is
\`nWindowDays\`) grouped by \`strGroupCol\`.

## Usage

``` r
pd_BucketCounts(dfDeath, dfSubjects, nWindowDays = 90, strGroupCol = "studyid")
```

## Arguments

- dfDeath:

  \`data.frame\` Mapped death data with \`subjid\` and \`death_dy\`.

- dfSubjects:

  \`data.frame\` Mapped subject data with \`subjid\` and
  \`strGroupCol\`.

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90.

- strGroupCol:

  \`character\` Column in \`dfSubjects\` to group by. Default:
  "studyid".

## Value

A \`data.frame\` with \`GroupID\`, \`Bucket\`, and \`n\` columns.
