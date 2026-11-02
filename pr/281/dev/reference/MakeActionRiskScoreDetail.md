# Per-KRI detail behind an action-status-weighted Site Risk Score

Returns one row per weighted KRI result with the ActionLog entry applied
to it, so a reader can see why an action-weighted score differs from the
original Site Risk Score. \[CalculateActionRiskScore()\] summarizes
these rows.

## Usage

``` r
MakeActionRiskScoreDetail(
  dfResults,
  dfWeights,
  dfActionLog,
  lActionFactors = c(`Open Action` = 1, `Closed Action` = 1, `Awaiting Triage` = 1,
    `No Action` = 0),
  strMissingState = c("error", "include", "exclude"),
  strMetricID = "Analysis_srs0002",
  dActionSnapshotDate = NULL,
  dActionExtractionDate = NULL
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

  ActionLog rows with the five-column result key, \`State\`, and
  \`ExtractionDate\`, for the same \`StudyID\` as \`dfResults\`. It may
  hold several entries per group and metric at different
  \`SnapshotDate\`s; for each group and metric the latest signal
  snapshot on or before \`dActionSnapshotDate\` is used within the
  selected frozen extraction. Multiple actions and signals at that
  snapshot are reduced using the largest configured factor. Identifiers
  must distinguish those rows.

- lActionFactors:

  Named numeric state-factor mapping. Defaults to include open, closed,
  and awaiting-triage findings and exclude no-action findings.

- strMissingState:

  Policy for a missing action state on a nonzero KRI weight: stop with
  an error, include the weight, or exclude the weight.

- strMetricID:

  Metric ID assigned to the action-weighted score.

- dActionSnapshotDate:

  \`Date\` "As of" date for ActionLog entries. \`NULL\` (default) uses
  the \`dfResults\` \`SnapshotDate\`. Must not be later than the
  \`dfResults\` \`SnapshotDate\`.

- dActionExtractionDate:

  \`Date\` or ISO \`YYYY-MM-DD\` cutoff for frozen ActionLog
  extractions. \`NULL\` uses the results snapshot date. The latest
  complete extraction on or before this cutoff is selected, without
  filling gaps from older extractions. Set an explicit date when
  replaying a scoring run whose ActionLog was frozen after the data
  snapshot. Signal snapshot dates do not establish when action states
  became known.

## Value

A data frame with one row per \`GroupLevel\`, \`GroupID\`, and
\`MetricID\` and columns \`StudyID\`, \`SnapshotDate\`, \`GroupLevel\`,
\`GroupID\`, \`MetricID\`, \`Flag\`, \`Weight\`, \`WeightMax\`,
\`ActionState\`, \`ActionSnapshotDate\` (the \`SnapshotDate\` of the
ActionLog entry applied), \`ActionSource\` (\`"ActionLog"\`,
\`"Missing"\`, or \`"Zero weight"\`), \`ActionFactor\`,
\`EffectiveWeight\`, \`ActionExtractionDate\`, \`RiskSignalID\`,
\`ActionID\`, and \`ActionCount\`. States and identifiers from multiple
rows are sorted and comma-separated; \`ActionCount\` counts distinct
actions.
