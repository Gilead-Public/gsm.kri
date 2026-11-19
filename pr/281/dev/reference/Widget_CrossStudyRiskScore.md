# Cross-Study Risk Score Widget

\`r lifecycle::badge("experimental")\`

A widget that generates an interactive cross-study risk score table.
Shows a summary view with click-to-expand details for each site.

Two XLSX downloads export the current view: the visible sites in their
displayed order, with study-filtered badge values. \* \*\*Site
summary\*\*: one row per site with Site, Studies, Enrolled, Avg SRS and
Max SRS, as in the collapsed view. \* \*\*Site/study detail\*\*: one row
per site, study and KRI, repeating the per-study enrollment, flag counts
and risk scores, with the KRI's flag, score, numerator, denominator and
metric, plus its action state, last addressed date, days ago and whether
it falls within 90 days when \`dfComparisonRiskDetail\` is supplied.

Files are generated in the browser; no data is uploaded.

For a working example see \[Cross-Study KRI
Report\](https://gilead-public.github.io/gsm.kri/examples/Example_CrossStudySRS.html).

## Usage

``` r
Widget_CrossStudyRiskScore(
  dfResults,
  dfMetrics,
  dfGroups,
  strGroupLevel = "Site",
  strRiskScoreMetric = "Analysis_srs0001",
  strComparisonRiskMetric = "Analysis_srs0002",
  strComparisonRiskLabel = "Adjusted Risk Score",
  dfComparisonRiskDetail = NULL
)
```

## Arguments

- dfResults:

  \`data.frame\` Full results data for details.

- dfMetrics:

  \`data.frame\` Metadata about metrics/KRIs.

- dfGroups:

  \`data.frame\` Metadata about groups (sites/studies).

- strGroupLevel:

  \`character\` The group level. Default is 'Site'.

- strRiskScoreMetric:

  \`character\` Risk score MetricID to display. Defaults to
  \`"Analysis_srs0001"\`.

- strComparisonRiskMetric:

  Optional metric ID displayed immediately after the risk score in each
  site's per-study rows, as in the site report. The column is omitted
  when the metric is absent from \`dfResults\` or is the same as
  \`strRiskScoreMetric\`. Default: \`"Analysis_srs0002"\`.

- strComparisonRiskLabel:

  Column label for the comparison risk score. Default: \`"Adjusted Risk
  Score"\`.

- dfComparisonRiskDetail:

  Optional per-KRI detail behind the comparison score, e.g. stacked
  \`Analysis_ActionRiskScoreDetail\` outputs of
  \[Analyze_ActionRiskScore()\] with \`StudyID\`, \`GroupID\`,
  \`MetricID\`, \`ActionState\`, \`LastActionedDate\`,
  \`DaysSinceAction\`, and \`ActionWindowDays\`. Each study/site/KRI
  cell with an action recorded 0 through 90 days before its assessment
  date is highlighted with the same colors and legend as the site
  report. Scores and flag colors are never changed. Ignored when the
  comparison metric is absent. Default: \`NULL\`.

## Value

An htmlwidget for cross-study risk score visualization.
