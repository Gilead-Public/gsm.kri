# Cross-Study Risk Score Widget

\`r lifecycle::badge("experimental")\`

A widget that generates an interactive cross-study risk score table.
Shows a summary view with click-to-expand details for each site.

For a working example see \[Cross-Study KRI
Report\](https://gilead-biostats.github.io/gsm.kri/examples/Example_CrossStudySRS.html).

## Usage

``` r
Widget_CrossStudyRiskScore(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site"
)
```

## Arguments

- dfResults:

  \`data.frame\` Full results data for details.

- dfMetrics:

  \`data.frame\` Metadata about metrics/KRIs.

- dfGroups:

  \`data.frame\` Metadata about groups (sites/studies).

- strGroupLevel:

  \`character\` The group level. Default is 'Site'.

## Value

An htmlwidget for cross-study risk score visualization.
