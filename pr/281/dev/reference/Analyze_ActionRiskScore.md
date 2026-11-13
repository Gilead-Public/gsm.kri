# Calculate an action-aware score and its detail together

Computes contributions once and summarizes the same rows into the
adjusted score. Source retrieval and persistence remain outside this
function.

## Usage

``` r
Analyze_ActionRiskScore(
  dfResults,
  dfWeights,
  dfActionLog,
  bUseSnapshotDate = FALSE,
  intActionWindowDays = 90L,
  strActionPolicy = "disposition",
  bActionHistoryComplete = FALSE,
  dActionExtractionDate = NULL,
  dActionAsOfDate = NULL,
  strMetricID = "Analysis_srs0002",
  bScoreSnapshotNoAction = bUseSnapshotDate
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

- bUseSnapshotDate:

  Use labelled work-item snapshot date proxies and recent, unambiguous
  No Action dispositions. Default FALSE. This does not manufacture
  verified decision coverage.

- intActionWindowDays:

  Optional nonnegative integer. When supplied, use
  \[MakeActionSummary()\] to gate decisions by recency and
  applicability. The default policy calculates review priority;
  \`"disposition"\` applies the configured state factor only to eligible
  recent decisions. NULL preserves legacy state weighting.

- strActionPolicy:

  Date-window policy. \`"recent-review"\` preserves the review-priority
  behavior: a recent applicable decision excludes its weight. The opt-in
  \`"disposition"\` draft applies \`lActionFactors\` only while that
  decision is recent and applicable. Defaults retain Open/Closed weights
  and exclude only a documented No Action decision. Expired/unknown
  evidence retains full weight. Neither policy changes the denominator
  or raw SRS.

- bActionHistoryComplete:

  Whether the selected extraction contains the complete decision
  history. Default FALSE; incomplete evidence never excludes a
  contribution in date-window mode.

- dActionExtractionDate:

  \`Date\` or ISO \`YYYY-MM-DD\` cutoff for frozen ActionLog
  extractions. \`NULL\` uses the results snapshot date, or
  \`dActionAsOfDate\` in date-window mode. The latest complete
  extraction on or before this cutoff is selected, without filling gaps
  from older extractions. Set an explicit date when replaying a scoring
  run whose ActionLog was frozen after the data snapshot. Signal
  snapshot dates do not establish when action states became known.

- dActionAsOfDate:

  Optional Date or ISO date for action age in date-window mode. Defaults
  to the results snapshot, not today's date.

- strMetricID:

  Metric ID assigned to the action-weighted score.

- bScoreSnapshotNoAction:

  Apply snapshot-based No Action exclusions. Defaults to
  bUseSnapshotDate. FALSE retains displayed proxy dates without using
  them to exclude contributions.

## Value

A list containing \`Analysis_Summary\` and
\`Analysis_ActionRiskScoreDetail\`, retaining the maximum-weight
denominator.
