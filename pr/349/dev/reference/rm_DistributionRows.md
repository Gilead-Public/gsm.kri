# Participant distribution rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Evaluable participants per group, KRI vital and flag. Study rows have
one bar per vital; country and site rows have one chart per vital.

## Usage

``` r
rm_DistributionRows(dfParticipants, strLevel = c("study", "country", "site"))
```

## Arguments

- dfParticipants:

  \`data.frame\` \`participants\` from \[rm_Classify()\].

- strLevel:

  \`character\` \`"study"\`, \`"country"\` or \`"site"\`.

## Value

A \`tibble\` with \`vital\`, \`GroupID\` (the vital's short label for
study rows), \`OuterGroupID\` (country for site rows, else \`NA\`),
\`Flag\`, \`n\` and \`Level\`, sorted so each chart's groups run from
the highest to the lowest % flagged. Only non-zero cells.
