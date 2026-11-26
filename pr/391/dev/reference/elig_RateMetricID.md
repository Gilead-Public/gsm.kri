# Rate metric of the eligibility results

The module passes qtl0001 only; older callers rename it (for example
\`"study_eligibility"\`), so otherwise the rate is the first metric.

## Usage

``` r
elig_RateMetricID(dfResults, lSetup = elig_Setup())
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results.

- lSetup:

  \`list\` from \[elig_Setup()\]; \`strRateMetricID\` is preferred.

## Value

\`character\` MetricID.
