# Premature-death category counts

\`r lifecycle::badge("experimental")\`

Counts the \[pd_Classify()\] category of each enrolled subject per
\`strGroupCol\`. \`.drop = FALSE\` keeps every category present for
every group so the stacked bar and its colors stay aligned.

## Usage

``` r
pd_BucketCounts(dfClassified, strGroupCol = "studyid", strOuterCol = NULL)
```

## Arguments

- dfClassified:

  \`data.frame\` Output of \[pd_Classify()\].

- strGroupCol:

  \`character\` Column to group by. Default "studyid".

- strOuterCol:

  \`character\` Optional parent column for a two-tier (multicategory)
  axis. \`NULL\` (default) is the flat one-tier count.

## Value

A \`data.frame\` with \`GroupID\`, \`Bucket\`, \`n\` (and \`Outer\` when
\`strOuterCol\` is set).
