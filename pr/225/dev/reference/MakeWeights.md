# Create Weight Table from Metrics Metadata

Generates a weight table by parsing comma-separated Flag and
RiskScoreWeight values from a metrics metadata data frame. This table
can be joined to KRI results to add weight information for risk score
calculations.

## Usage

``` r
MakeWeights(dfMetrics)
```

## Arguments

- dfMetrics:

  \`data.frame\` Metrics metadata containing at least \`MetricID\`,
  \`Flag\`, and \`RiskScoreWeight\` columns. The \`Flag\` and
  \`RiskScoreWeight\` columns should contain comma-separated values that
  will be parsed into individual rows.

## Value

\`data.frame\` Weight table with one row per MetricID-Flag combination,
containing:

- MetricID:

  Unique metric identifier

- Flag:

  Individual flag value (numeric)

- Weight:

  Weight associated with the flag (numeric)

- WeightMax:

  Maximum weight for the metric (numeric)

## Details

The function performs the following steps:

1.  Filters to rows with non-NA Flag and RiskScoreWeight values

2.  Splits comma-separated Flag and RiskScoreWeight strings into lists

3.  Expands to one row per flag-weight combination

4.  Converts Flag and Weight to numeric values

5.  Calculates WeightMax as the maximum Weight per MetricID

## Examples

``` r
# Create weight table from gsm.core::reportingMetrics
dfWeights <- MakeWeights(gsm.core::reportingMetrics)

# Join to KRI results
library(dplyr)
dfResults <- gsm.core::reportingResults %>%
  left_join(dfWeights, by = c("MetricID", "Flag"))
```
