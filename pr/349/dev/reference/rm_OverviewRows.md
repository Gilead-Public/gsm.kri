# Study overview rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Participant counts per KRI vital for the whole study, each country and
each site, so the report's filter script only picks rows. A participant
is evaluable for a vital with at least one window (\`Denominator \>
0\`).

## Usage

``` r
rm_OverviewRows(dfParticipants)
```

## Arguments

- dfParticipants:

  \`data.frame\` \`participants\` from \[rm_Classify()\].

## Value

A \`tibble\` with \`Level\` (\`"study"\`, \`"country"\` or \`"site"\`),
\`GroupID\`, \`vital\`, \`enrolled\`, \`evaluable\`, \`amber\` and
\`red\`.
