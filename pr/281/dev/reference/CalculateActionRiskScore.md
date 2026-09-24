# Calculate an action-status-weighted Site Risk Score

Applies Central Monitoring ActionLog states to existing KRI flag
weights. Action factors affect only numerator contributions; the
denominator remains the full maximum-risk denominator used by
\[CalculateRiskScore()\].

## Usage

``` r
CalculateActionRiskScore(
  dfResults,
  dfWeights,
  dfActionLog,
  lActionFactors = c(`Open Action` = 1, `Closed Action` = 1, `Awaiting Triage` = 1,
    `No Action` = 0),
  strMissingState = c("error", "include", "exclude"),
  strMetricID = "Analysis_srs0002"
)
```

## Arguments

- dfResults:

  Current persisted KRI result rows. Must contain one \`StudyID\` and
  one \`SnapshotDate\` plus \`GroupLevel\`, \`GroupID\`, \`MetricID\`,
  and \`Flag\`.

- dfWeights:

  Risk score weights with \`MetricID\`, \`Flag\`, \`Weight\`, and
  \`WeightMax\`.

- dfActionLog:

  Scoring-ready ActionLog rows with the five-column result key,
  \`State\`, and \`ExtractionDate\`. The scoring key must be unique.

- lActionFactors:

  Named numeric state-factor mapping. Defaults to include open, closed,
  and awaiting-triage findings and exclude no-action findings.

- strMissingState:

  Policy for a missing action state on a nonzero KRI weight: stop with
  an error, include the weight, or exclude the weight.

- strMetricID:

  Metric ID assigned to the action-weighted score.

## Value

A canonical risk score data frame with the same output schema as
\[CalculateRiskScore()\].
