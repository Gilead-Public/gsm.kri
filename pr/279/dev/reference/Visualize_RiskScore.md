# Visualize Risk Score

Creates an interactive risk score widget for cross-study visualization.

## Usage

``` r
Visualize_RiskScore(dfResults, dfMetrics, dfGroups, strGroupLevel = "Site")
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results from CalculateRiskScore

- dfMetrics:

  \`data.frame\` Metric metadata from gsm.core::reportingMetrics

- dfGroups:

  \`data.frame\` Group metadata from gsm.core::reportingGroups

- strGroupLevel:

  \`character\` The group level to filter the risk score data. Default
  is 'Site'.

## Details

For a working example see \[Cross-Study KRI
Report\](https://gilead-biostats.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
