# reportingActionLog Dataset

Deterministic longitudinal ActionLog records aligned with flagged site
KRI rows in \[gsm.core::reportingResults\], for demonstrating
\[CalculateActionRiskScore()\].

## Usage

``` r
reportingActionLog
```

## Format

A data frame with \`r nrow(reportingActionLog)\` rows and \`r
ncol(reportingActionLog)\` columns:

- StudyID:

  unique study identifier

- SnapshotDate:

  date of the KRI snapshot

- GroupLevel:

  level of grouping variable

- GroupID:

  grouping variable

- MetricID:

  unique metric identifier

- State:

  ActionLog state

- ExtractionDate:

  date the synthetic ActionLog was extracted

- WorkItemID:

  synthetic ActionLog work item identifier

- WorkItemURL:

  synthetic ActionLog work item URL

- RiskSignalDuplicateFlag:

  whether the signal duplicates a scoring key

- RelevantSnapshotDate:

  relevant snapshot across the signal history

- RelevantSnapshotFlag:

  whether this row is the relevant snapshot

- RiskSignalAge:

  age of the signal in days

- AssignedTo:

  assignee of the risk signal

- SignalDescription:

  description of the risk signal

- RecommendedAction:

  recommended action for the risk signal

- ActionTaken:

  action taken in response to the risk signal

- CTMSID:

  linked CTMS identifier

- CreatedDate:

  date the risk signal was created

- ResolvedDate:

  date the risk signal was resolved

- FunctionalArea:

  functional area owning the risk signal

- GroupLabel:

  display label for the group

- MetricLabel:

  display label for the metric

- MetricAbbreviation:

  metric abbreviation

- Country:

  site country

## Source

Simulated with \`gsm.datasim::simulate_action_log()\` by
\`data-raw/reportingActionLog.R\`, ported from
Gilead-Public/gsm.core#183.
