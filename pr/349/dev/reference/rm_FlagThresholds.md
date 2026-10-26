# Repeat Measurements participant flag thresholds

Amber and Red thresholds for a participant flag rule. Count thresholds
default to 2 and 3 repeating windows. Rate thresholds default to the
\`kri0020\` metric thresholds so that the participant flag matches the
site KRI, or 0.2 and 0.3 without them.

## Usage

``` r
rm_FlagThresholds(
  strFlagRule = c("count", "rate"),
  vFlagThresholds = NULL,
  dfMetrics = NULL
)
```

## Arguments

- strFlagRule:

  \`character\` \`"count"\` (repeating windows) or \`"rate"\` (share of
  windows that repeat).

- vFlagThresholds:

  \`numeric\` Amber then Red threshold, or \`NULL\` for the defaults.
  Rates are fractions.

- dfMetrics:

  \`data.frame\` Metric metadata with \`ID\` and \`Threshold\`.

## Value

A \`numeric\` vector: Amber, then Red.
