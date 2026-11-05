# Calculate an action-aware Site Risk or Review Priority Score

Applies dated monitoring decisions or legacy ActionLog state factors to
KRI weights. Action factors affect only numerator contributions; the
denominator remains the full maximum-risk denominator used by
\[CalculateRiskScore()\]. The per-KRI contributions behind the score are
available from \[MakeActionRiskScoreDetail()\].

## Usage

``` r
CalculateActionRiskScore(
  dfResults,
  dfWeights,
  dfActionLog,
  lActionFactors = c(`Open Action` = 1, `Closed Action` = 1, `Awaiting Triage` = 1,
    `No Action` = 0),
  strMissingState = c("error", "include", "exclude"),
  strMetricID = "Analysis_srs0002",
  dActionSnapshotDate = NULL,
  dActionExtractionDate = NULL,
  intActionWindowDays = NULL,
  dActionAsOfDate = NULL,
  bActionHistoryComplete = FALSE,
  strActionPolicy = c("recent-review", "disposition")
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
  and awaiting-triage findings and exclude no-action findings. Used by
  legacy mode and the opt-in \`"disposition"\` policy; ignored by
  \`"recent-review"\`.

- strMissingState:

  Policy for a missing action state on a nonzero KRI weight: stop with
  an error, include the weight, or exclude the weight. Used only in
  legacy mode; date-window mode always includes unknown evidence.

- strMetricID:

  Metric ID assigned to the action-weighted score.

- dActionSnapshotDate:

  \`Date\` "As of" date for ActionLog entries. \`NULL\` (default) uses
  the \`dfResults\` \`SnapshotDate\`. Must not be later than the
  \`dfResults\` \`SnapshotDate\`.

- dActionExtractionDate:

  \`Date\` or ISO \`YYYY-MM-DD\` cutoff for frozen ActionLog
  extractions. \`NULL\` uses the results snapshot date, or
  \`dActionAsOfDate\` in date-window mode. The latest complete
  extraction on or before this cutoff is selected, without filling gaps
  from older extractions. Set an explicit date when replaying a scoring
  run whose ActionLog was frozen after the data snapshot. Signal
  snapshot dates do not establish when action states became known.

- intActionWindowDays:

  Optional nonnegative integer. When supplied, use
  \[MakeActionSummary()\] to gate decisions by recency and
  applicability. The default policy calculates review priority;
  \`"disposition"\` applies the configured state factor only to eligible
  recent decisions. NULL preserves legacy state weighting.

- dActionAsOfDate:

  Optional Date or ISO date for action age in date-window mode. Defaults
  to the results snapshot, not today's date.

- bActionHistoryComplete:

  Whether the selected extraction contains the complete decision
  history. Default FALSE; incomplete evidence never excludes a
  contribution in date-window mode.

- strActionPolicy:

  Date-window policy. \`"recent-review"\` preserves the review-priority
  behavior: a recent applicable decision excludes its weight. The opt-in
  \`"disposition"\` draft applies \`lActionFactors\` only while that
  decision is recent and applicable. Defaults retain Open/Closed weights
  and exclude only a documented No Action decision. Expired/unknown
  evidence retains full weight. Neither policy changes the denominator
  or raw SRS.

## Value

A canonical risk score data frame with the same output schema as
\[CalculateRiskScore()\].
