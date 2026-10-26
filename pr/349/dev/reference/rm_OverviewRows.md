# Study overview rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

One row per vital for the whole study, whatever the report's filters:
sites evaluated and flagged (see \[rm_SiteFlagRows()\]) and participants
evaluable and flagged. A participant is evaluable for a vital when their
flag is Red, Amber or Green. The report's filter script computes the
participant counts in the browser so that they follow the reviewer's
flag settings.

## Usage

``` r
rm_OverviewRows(lClass, dfSites = rm_SiteFlagRows(lClass))
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

- dfSites:

  \`data.frame\` Output of \[rm_SiteFlagRows()\].

## Value

A \`tibble\` in vital order with \`vital\`, \`label\`, \`metric\`,
\`site_source\` (\`"KRI"\` or \`"report"\`), \`sites\`,
\`sites_evaluated\`, \`site_amber\`, \`site_red\`, \`enrolled\`,
\`evaluable\`, \`amber\` and \`red\`.
