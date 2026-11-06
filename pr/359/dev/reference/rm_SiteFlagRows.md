# Site flags for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

One flag per site and measure. A KRI measure with \`kri0020a\`–\`f\`
site results takes the latest KRI flag (\`source = "KRI"\`). Every other
measure (height, BSA, paired BP, or a KRI measure without results) is
flagged in the report with the \`kri0020\` workflow steps (\`source =
"report"\`): \[gsm.core::Input_Rate()\], \[gsm.core::Transform_Rate()\],
\[gsm.core::Analyze_Identity()\] and \[gsm.core::Flag()\] on the
participants' windows, with the site rule of \[rm_SiteRule()\]. A site
is not evaluated (\`flag\` \`NA\`) without windows, below the accrual
threshold or without a KRI result.

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
not evaluated) and \`source\`, one row per measure and site with
enrolled participants. A site whose participants have more than one
country lists them in \`country\`, comma-separated.
