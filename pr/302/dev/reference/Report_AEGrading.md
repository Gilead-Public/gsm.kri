# Report_AEGrading function

\`r lifecycle::badge("experimental")\`

Generates an AE severity grading report: the study-wide grade
distribution, a grade-by-site stacked bar chart, and the sites flagged
by the grading metric.

## Usage

``` r
Report_AEGrading(
  dfResults = NULL,
  lListings = NULL,
  strMetricID = "Analysis_kri0016",
  nMinAE = 20,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_AEGrading.Rmd", package = "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results data. Filtered internally to
  site-level rows for \`strMetricID\`; used to mark and list flagged
  sites. When \`NULL\` the chart still renders, without flags.

- lListings:

  \`list\` containing \`Mapped_AE\` and \`Mapped_SUBJ\`.

- strMetricID:

  \`string\` MetricID of the grading metric to report on. Default:
  \`"Analysis_kri0016"\` (High-Grade AE Proportion). Use
  \`"Analysis_kri0017"\` for the Low-Grade AE Proportion metric.

- nMinAE:

  \`numeric\` Minimum number of graded AEs for a site to appear in the
  chart. Default: 20.

- strOutputDir:

  \`string\` Output directory. Default: working directory.

- strOutputFile:

  \`string\` Output filename. Default: \`Report_AEGrading.html\`.

- strInputPath:

  \`string\` Path to the template \`Rmd\`.

## Value

File path of the saved report HTML, returned invisibly.
