# Site flag rule for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The \`kri0020\` site rule: Amber and Red at the metric \`Threshold\`
(default 20% and 30% of windows repeat) for sites with at least the
metric \`AccrualThreshold\` windows (default 3).

## Usage

``` r
rm_SiteRule(dfMetrics = NULL)
```

## Arguments

- dfMetrics:

  \`data.frame\` Reporting metrics. Optional.

## Value

A \`list\` with \`thresholds\` (Amber, Red; fractions) and \`accrual\`.
