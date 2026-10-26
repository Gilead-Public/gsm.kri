# Site flags for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

One flag per site and vital. A KRI vital with \`kri0020a\`–\`f\` site
results takes the latest KRI flag (\[rm_SiteFlags()\]; \`source =
"KRI"\`). Every other vital (height, BSA, paired BP, or a KRI vital
without results) is flagged in the report like the KRI (\`source =
"report"\`): the site's repeating windows over its windows (summed over
its participants) against the site rule of \[rm_SiteRule()\]. A site is
not evaluated (\`flag\` \`NA\`) below the accrual threshold or without a
KRI result.

## Usage

``` r
rm_SiteFlagRows(lClass, dfResults = NULL, dfMetrics = NULL)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

- dfResults:

  \`data.frame\` Reporting results. Optional.

- dfMetrics:

  \`data.frame\` Reporting metrics. Optional.

## Value

A \`tibble\` with \`vital\`, \`country\`, \`invid\`, \`Numerator\`,
\`Denominator\`, \`flag\` (\`0\` Green, \`1\` Amber, \`2\` Red, \`NA\`
not evaluated) and \`source\`, one row per vital and site with enrolled
participants.
