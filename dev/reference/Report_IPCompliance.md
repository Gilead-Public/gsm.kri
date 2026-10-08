# Report_IPCompliance function

\`r lifecycle::badge("experimental")\`

Generates the IP monitoring report: IP non-starters and premature
treatment discontinuation for every enrolled participant, at study,
country and site level, with a participant listing.

## Usage

``` r
Report_IPCompliance(
  dfResults = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_IPCompliance.Rmd", package = "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results; the latest \`SnapshotDate\` is
  "today" unless \`dSnapshotDate\` is given.

- lListings:

  \`list\` with \`Mapped_IPNS\`, \`Mapped_SUBJ\` and
  \`Mapped_STUDCOMP\`. Without \`drv_treatment_discontinuation_dt\` in
  \`Mapped_SUBJ\` the report runs without premature treatment
  discontinuation.

- dSnapshotDate:

  \`Date\` "Today" for the day counts. Default: the latest
  \`dfResults\$SnapshotDate\`.

- strOutputDir:

  \`string\` Output directory. Default: working directory.

- strOutputFile:

  \`string\` Output filename. Default: \`Report_IPCompliance.html\`.

- strInputPath:

  \`string\` Path to the template \`Rmd\`.

## Value

File path of the saved report HTML, returned invisibly.
