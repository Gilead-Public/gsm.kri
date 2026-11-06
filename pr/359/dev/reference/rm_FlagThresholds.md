# Repeat Measurements participant flag thresholds

\`r lifecycle::badge("experimental")\`

Amber and Red thresholds for a participant flag rule. Count thresholds
default to 2 and 3 repeating windows. Rate thresholds default to the
\`Threshold\` of the \`kri0020\` / \`cou0020\` metrics, or 0.2 and 0.3
without them.

The rate defaults are the site-level KRI thresholds reused at the
participant grain, so a participant is flagged at the same share of
repeating windows as a site. That is a starting point rather than a
participant-level calibration: a participant has far fewer windows than
a site, so one repeating window moves the rate a lot. Pass
\`vFlagThresholds\` (or \`vFlagThresholds\` to
\[Report_RepeatMeasurements()\], or the report's Settings panel) to use
participant-specific thresholds.

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
