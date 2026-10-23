# Report_IPMonitoring function

\`r lifecycle::badge("experimental")\`

Generates the IP monitoring report: IP non-starters and premature
treatment discontinuation for every enrolled participant, at study,
country and site level, with a participant listing.

## Usage

``` r
Report_IPMonitoring(
  dfResults = NULL,
  lListings = NULL,
  dSnapshotDate = NULL,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_IPMonitoring.Rmd", package = "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results; the latest \`SnapshotDate\` is
  "today" unless \`dSnapshotDate\` is given.

- lListings:

  \`list\` with \`Mapped_IPNS\`, \`Mapped_SUBJ\` and
  \`Mapped_STUDCOMP\`. Without \`drv_drg_completion\` in
  \`Mapped_SUBJ\`, dosed participants show as Unrecognized status and
  the treatment completion figures and reasons are not available.

- dSnapshotDate:

  \`Date\` "Today" for the day counts. Default: the latest
  \`dfResults\$SnapshotDate\`.

- strOutputDir:

  \`string\` Output directory. Default: working directory.

- strOutputFile:

  \`string\` Output filename. Default: \`Report_IPMonitoring.html\`.

- strInputPath:

  \`string\` Path to the template \`Rmd\`.

## Value

File path of the saved report HTML, returned invisibly.
