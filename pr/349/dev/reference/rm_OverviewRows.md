# Study overview rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Participant counts per flagged vital for the whole study, each country
and each site. A participant is evaluable for a vital when their flag is
Red, Amber or Green (enough windows for the flag rule). The report's
filter script computes the same counts in the browser so that they
follow the reviewer's flag settings.

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
