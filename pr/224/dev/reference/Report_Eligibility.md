# Report_Eligibility function

\`r lifecycle::badge("stable")\`

This function generates a Eligibility report based on the provided
inputs.

## Usage

``` r
Report_Eligibility(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_Eligibility.Rmd", package = "gsm.kri")
)
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results data.

- dfMetrics:

  \`data.frame\` Analysis metrics data.

- dfGroups:

  \`data.frame\` Analysis groups data.

- lListings:

  \`list\` List containing appropriate dataset to display for
  eligiiblity listing

- strOutputDir:

  The output directory path for the generated report. If not provided,
  the report will be saved in the current working directory.

- strOutputFile:

  The output file name for the generated report. If not provided, the
  report will be named based on the study ID, Group Level and Date.

- strInputPath:

  \`string\` or \`fs_path\` Path to the template \`Rmd\` file.

## Value

File path of the saved report html is returned invisibly. Save to object
to view absolute output path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Run study-level Eligibility report.
dfResults <- gsm.core::reportingResults_study %>%
  filter(MetricID %in% "Analysis_qtl0001") %>%
  mutate(MetricID = "study_eligibility")

dfMetrics <- gsm.core::reportingMetrics_study %>%
  filter(MetricID %in% "Analysis_qtl0001") %>%
  mutate(MetricID = "study_eligibility")

dfGroups <- gsm.core::reportingGroups_study

mappings_wf <- gsm.core::MakeWorkflowList(
  strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
  strPath = "workflow/1_mappings",
  strPackage = "gsm.mapping"
)
mappings_spec <- gsm.mapping::CombineSpecs(mappings_wf)
lRaw <- map_depth(
  list(gsm.core::lSource),
  1,
  gsm.mapping::Ingest,
  mappings_spec
)
mapped <- map_depth(lRaw, 1, ~ gsm.core::RunWorkflows(mappings_wf, .x))

# test rendering of report
lListings <- list(
  IE = mapped[[1]]$Mapped_EXCLUSION
)

lParams <- list(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings
)

# Local call to render function - run from pkg root
Report_Eligibility(
  lParams = lParams,
  strOutputDir = file.path(getwd(), "pkgdown", "assets", "examples"),
  strOutputFile = "Example_Eligibility.html",
  strInputPath = file.path(
    getwd(), "pkgdown", "menus", "examples", "report/Report_Eligibility.Rmd"
  )
)
} # }
```
