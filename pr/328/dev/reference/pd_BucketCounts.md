# Premature-death category counts

\`r lifecycle::badge("experimental")\`

Counts the \[pd_Classify()\] category of each enrolled subject per
\`strGroupCol\`. \`.drop = TRUE\` emits only the (group, category) pairs
that actually occur; the \`Bucket\` factor still carries the full level
vocabulary, so colors and display order stay aligned. A category nobody
lands in is therefore absent from the counts, and downstream gets no
legend entry for it.

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
