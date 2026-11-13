# Summarize dated monitoring decisions across KRI signal snapshots

Returns one row per current site/KRI, independently of risk score
weights. Only explicit \`ActionedDate\` values with a populated
\`ActionedDateSource\` establish action recency. Signal creation,
resolution, and extraction dates are never substituted. The latest
complete extraction is selected first.

## Usage

``` r
MakeActionSummary(
  dfResults,
  dfActionLog,
  intActionWindowDays = 90L,
  dActionAsOfDate = NULL,
  dActionExtractionDate = NULL,
  bActionHistoryComplete = FALSE
)
```

## Arguments

- dfResults:

  Current persisted KRI result rows. Must contain one \`StudyID\` and
  one \`SnapshotDate\` plus \`GroupLevel\`, \`GroupID\`, \`MetricID\`,
  and \`Flag\`.

- dfActionLog:

  ActionLog rows with the five-column result key, \`State\`, and
  \`ExtractionDate\`, for the same \`StudyID\` as \`dfResults\`. It may
  hold several entries per group and metric at different
  \`SnapshotDate\`s; for each group and metric the latest signal
  snapshot on or before \`dActionSnapshotDate\` is used within the
  selected frozen extraction. Multiple actions and signals at that
  snapshot are reduced using the largest configured factor. Identifiers
  must distinguish those rows.

- intActionWindowDays:

  Nonnegative integer action window, inclusive at both ends. Default: 90
  days.

- dActionAsOfDate:

  Date or ISO date for assessing action age. Defaults to the results
  snapshot. May be later for a subsequent monitoring review.

- dActionExtractionDate:

  \`Date\` or ISO \`YYYY-MM-DD\` cutoff for frozen ActionLog
  extractions. \`NULL\` uses the results snapshot date, or
  \`dActionAsOfDate\` in date-window mode. The latest complete
  extraction on or before this cutoff is selected, without filling gaps
  from older extractions. Set an explicit date when replaying a scoring
  run whose ActionLog was frozen after the data snapshot. Signal
  snapshot dates do not establish when action states became known.

- bActionHistoryComplete:

  Whether the selected extraction contains the complete decision
  history. Default: FALSE. Incomplete history cannot establish that a
  KRI was never addressed or justify score exclusion.

## Value

Current KRI keys and flags, last known action date, age, recency, source
identifiers, coverage evidence, \`RecentlyAddressed\`, and an
\`ActionReason\`. \`ActionRecency\` is Recent, Expired, Never, or
Unknown. Never requires complete history; undated evidence remains
Unknown. Dates older than the window are retained. The summary is
independent of weights and does not change the original KRI results or
risk score.

## Details

Enrich the source-neutral ActionLog with authoritative \`ActionedDate\`
(Date), \`ActionedDateSource\` (character), \`ActionedFlag\` (the
numeric flag reviewed), and \`ActionScope\` (\`"SiteMetric"\` or
\`"Signal"\`). These additive fields describe documented monitoring
decisions, not inferred work-item activity. A dated No Action decision
may qualify; automatic creation does not. Missing event data remain
unknown.

A SiteMetric decision can cover repeated signals across snapshots; a
Signal decision covers only its own snapshot. Increased severity,
changed flag direction, mismatched optional \`RiskEpisodeID\`, any
explicit \`ActionReopened\`, critical actions, or undated decisions
prevent exclusion. When episode identity is unavailable, SiteMetric
scope must explicitly mean that the decision applies to the ongoing
site/KRI finding. Conflicting latest-day severity, scope, or episode
evidence also prevents exclusion; deterministic ID ordering selects a
representative audit row only. Existing ActionLogs without these
additive event fields remain supported, but do not establish an action
date. The extractor must obtain authoritative decision dates and
evidence from its source system; a current-state read alone is not a
decision history.

## Examples

``` r
results <- data.frame(
  StudyID = "Study-1", SnapshotDate = as.Date("2026-11-04"),
  GroupLevel = "Site", GroupID = c("1001", "1002"),
  MetricID = "Analysis_kri0001", Flag = 2
)
actions <- results[1, ]
actions$SnapshotDate <- as.Date("2026-10-01")
actions$ExtractionDate <- as.Date("2026-11-04")
actions$State <- "Closed Action"
actions$RiskSignalID <- "RS-1"
actions$ActionID <- "ACT-1"
actions$ActionedDate <- as.Date("2026-10-15")
actions$ActionedDateSource <- "Monitoring decision"
actions$ActionedFlag <- 2
actions$ActionScope <- "SiteMetric"
MakeActionSummary(results, actions, bActionHistoryComplete = TRUE)
#>   StudyID SnapshotDate GroupLevel GroupID         MetricID Flag RiskEpisodeID
#> 1 Study-1   2026-11-04       Site    1001 Analysis_kri0001    2          <NA>
#> 2 Study-1   2026-11-04       Site    1002 Analysis_kri0001    2          <NA>
#>   ActionCount HasUndatedDecision HasReopenedAction HasCriticalAction
#> 1           1              FALSE             FALSE             FALSE
#> 2           0              FALSE             FALSE             FALSE
#>   HasConflictingLatestDecision LastActionedDate  ActionedDateSource
#> 1                        FALSE       2026-10-15 Monitoring decision
#> 2                        FALSE             <NA>                <NA>
#>   ActionedFlag ActionScope ActionSignalSnapshotDate   ActionState
#> 1            2  SiteMetric               2026-10-01 Closed Action
#> 2           NA        <NA>                     <NA>          <NA>
#>   ActionRiskSignalID ActionID ActionRiskEpisodeID ActionExtractionDate
#> 1               RS-1    ACT-1                <NA>           2026-11-04
#> 2               <NA>     <NA>                <NA>           2026-11-04
#>   ActionAsOfDate ActionWindowDays ActionHistoryComplete DaysSinceAction
#> 1     2026-11-04               90                  TRUE              20
#> 2     2026-11-04               90                  TRUE              NA
#>   ActionRecency ActionCoverageReason DecisionCoversFinding RecentlyAddressed
#> 1        Recent   Recently addressed                  TRUE              TRUE
#> 2         Never    No dated decision                 FALSE             FALSE
#>         ActionReason
#> 1 Recently addressed
#> 2              Never
```
