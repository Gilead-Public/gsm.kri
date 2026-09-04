# Visualize Risk Score

Creates an interactive risk score widget for cross-study visualization.

## Usage

``` r
Visualize_RiskScore(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  strRiskScoreMetric = "Analysis_srs0001"
)
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

- strRiskScoreMetric:

  \`character\` Risk score MetricID to display. Defaults to
  \`"Analysis_srs0001"\`.

## Details

For a working example see \[Cross-Study KRI
Report\](https://gilead-public.github.io/gsm.kri/examples/Example_CrossStudySRS.html).
