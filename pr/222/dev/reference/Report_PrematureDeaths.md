# Report_PrematureDeaths function

\`r lifecycle::badge("experimental")\`

Generates a premature-deaths domain report with stacked sections per
group level (Study -\> Country -\> Site) and a patient listing.

## Usage

``` r
Report_PrematureDeaths(
  dfResults = NULL,
  dfMetrics = NULL,
  dfGroups = NULL,
  lListings = NULL,
  nWindowDays = 90,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_PrematureDeaths.Rmd", package = "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results data (must contain
  \`Analysis_pat0015\` rows for the patient listing).

- dfMetrics:

  \`data.frame\` Analysis metrics data.

- dfGroups:

  \`data.frame\` Analysis groups data.

- lListings:

  \`list\` containing \`Mapped_Death\` and \`Mapped_SUBJ\` frames, and
  optionally \`Mapped_EXCLUSION\` (adds the Eligibility Status column to
  the patient listing).

- nWindowDays:

  \`numeric\` Premature-death window in days. Default: 90. \*\*Must
  equal the \`meta.WindowDays\` used when \`pat0015\` produced
  \`dfResults\`.\*\* The charts recompute premature status live from
  \`Mapped_Death\` at this \`nWindowDays\`, while the patient listing
  trusts \`pat0015\`'s \`Flag == 2\` rows (flagged at analysis-time
  \`meta.WindowDays\`). If the two windows differ the report's charts
  and listing silently disagree; the Rmd emits a \`cli_alert_warning\`
  when it detects this mismatch (see the Rmd template).

- strOutputDir:

  \`string\` Output directory. Default: working directory.

- strOutputFile:

  \`string\` Output filename. Default: \`Report_PrematureDeaths.html\`.

- strInputPath:

  \`string\` Path to the template \`Rmd\`.

## Value

File path of the saved report HTML, returned invisibly.
