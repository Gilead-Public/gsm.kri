# Opt-in modern KRI report (v2) building blocks

\`r lifecycle::badge("experimental")\`

Internal helpers used by \`inst/report/Report_KRI_v2.Rmd\`, an opt-in
template rendered with \`Report_KRI(strInputPath = system.file("report",
"Report_KRI_v2.Rmd", package = "gsm.kri"))\`. Each helper returns
\[htmltools::tags\] so the whole page can be knit as a single tag tree,
which keeps htmlwidget dependencies de-duplicated.

## Usage

``` r
ReportV2_Summary(dfResults, dfMetrics = NULL)

ReportV2_Masthead(lSetup)

ReportV2_KPICards(lSummary, strGroupLevel = "Site")

ReportV2_Takeaways(lSummary, dfResults, dfMetrics, dfGroups)

ReportV2_Nav(dfResults, dfMetrics)

ReportV2_FlagChanges(dfResults, dfMetrics, dfGroups)

ReportV2_MetricCard(lCharts, lMetric, dfResults)

ReportV2_MetricReference(dfMetrics)

ReportV2_Topbar(lSetup, dfResults, dfGroups, dfMetrics = NULL)

ReportV2_Dependencies()

ReportV2_SiteData(dfResults, dfMetrics, dfGroups, lCharts = NULL)

ReportV2_SitesTab(lSiteData)

ReportV2_TabBar(strGroupLevel = "Site", lCounts = list())
```

## Arguments

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

- dfMetrics:

  \`data.frame\` Metric-specific metadata for use in charts and
  reporting. Created by passing an \`lWorkflow\` object to
  \[MakeMetric()\]. Expected columns: \`File\`, \`MetricID\`, \`Group\`,
  \`Abbreviation\`, \`Metric\`, \`Numerator\`, \`Denominator\`,
  \`Model\`, \`Score\`, and \`Threshold\`. For more details see the Data
  Model vignette: \`vignette("DataModel", package = "gsm.core")\`.

- lSetup:

  \`list\` Output of \[Report_Setup()\].

- lSummary:

  \`list\` Output of \`ReportV2_Summary()\`.

- strGroupLevel:

  \`character\` Group level used in labels, e.g. \`"Site"\`.

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lCharts:

  \`list\` Charts for a single metric, as produced by \[MakeCharts()\].

- lMetric:

  \`list\` Metadata for a single metric (one row of \`dfMetrics\`).

- lSiteData:

  \`list\` Output of \`ReportV2_SiteData()\`.

- lCounts:

  \`list\` Optional badges per tab, named \`overview\`, \`sites\`,
  \`metrics\`.

## Functions

- `ReportV2_Summary()`: Headline counts for the current snapshot.

- `ReportV2_Masthead()`: Study masthead with status chips and enrollment
  progress.

- `ReportV2_KPICards()`: KPI cards with change versus the previous
  snapshot.

- `ReportV2_Takeaways()`: Key takeaways for the current snapshot.

- `ReportV2_Nav()`: KRI list with per-KRI flag badges (Metrics tab).

- `ReportV2_FlagChanges()`: Flag changes grouped by site or by KRI, with
  a perspective switch.

- `ReportV2_MetricCard()`: A collapsible card holding the charts for one
  KRI.

- `ReportV2_MetricReference()`: Reference cards with KRI definitions.

- `ReportV2_Topbar()`: Sticky top bar with the global group search.

- `ReportV2_Dependencies()`: Stylesheet and script for the v2 template.

- `ReportV2_SiteData()`: Per-site risk data behind the Sites tab: site
  summaries ranked by risk score, one cell per site and KRI, and
  KRI-level study rates. Each cell carries flag bands converted to the
  rate scale, so the site panel can draw a bullet chart of the site rate
  against the study rate.

- `ReportV2_SitesTab()`: Sites tab: risk-ranked heatmap (left) and site
  details (right).

- `ReportV2_TabBar()`: Main tab bar (Overview, Sites, Metrics).
