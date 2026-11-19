# Report_Eligibility function

\`r lifecycle::badge("stable")\`

Generates the Eligibility report: enrolled participants by eligibility
status at study, country and site level, flag sources, EDC I/E criteria
views, the Ineligibility listing and the eligibility rules.

The study picks the mode with \`strMode\`: - \*\*Basic\*\* (default,
every study): two statuses, Ineligible (\`Source != 'Neither'\`) and No
Eligibility Risk, computed as before. - \*\*Pilot\*\*: a third status,
Potentially Ineligible, from the \`edc_query\` and \`edc_pd\` columns
(gsm.roadmap#113). With no data in either, the report warns and falls
back to basic.

## Usage

``` r
Report_Eligibility(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = dfGroups,
  lListings = lListings,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file("report", "Report_Eligibility.Rmd", package = "gsm.kri"),
  strMode = c("basic", "pilot"),
  dfStatusHistory = NULL
)
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results: the study-level eligibility rate
  (qtl0001).

- dfMetrics:

  \`data.frame\` Analysis metrics data.

- dfGroups:

  \`data.frame\` Analysis groups data.

- lListings:

  \`list\` with \`IE_denom\` (\`Mapped_EXCLUSION\`), \`IE_num\` (its
  ineligible rows) and, optionally, \`IE_records\`.

- strOutputDir:

  The output directory path for the generated report. If not provided,
  the report will be saved in the current working directory.

- strOutputFile:

  The output file name for the generated report. If not provided, the
  report will be named \`Report_Eligibility.html\`.

- strInputPath:

  \`string\` or \`fs_path\` Path to the template \`Rmd\` file.

- strMode:

  \`character\` \`"basic"\` (default) or \`"pilot"\`.

- dfStatusHistory:

  \`data.frame\` Status history (level 3). Default: \`NULL\`.

## Value

File path of the saved report html is returned invisibly. Save to object
to view absolute output path.

## Data contract

Each level is optional and unlocks more of the report. 1.
\*\*Columns\*\* on \`lListings\$IE_denom\` (\`Mapped_EXCLUSION\`),
\`"Y"\`/\`"N"\`: \`pd_important\` and \`pd_nonimportant\` (split the PD
source), \`edc_query\` and \`edc_pd\` (pilot mode; \`NA\` throughout
when the source is not delivered, and the listing shows "N/A"). A
participant is Ineligible when \`Source != 'Neither'\`, otherwise
Potentially Ineligible when \`edc_query\` or \`edc_pd\` is \`"Y"\`,
otherwise No Eligibility Risk. \`Source\` itself never carries
Potentially Ineligible. 2. \*\*Records\*\*: \`lListings\$IE_records\`,
one row per record behind a flag, with \`studyid\`, \`subjid\`,
\`source\` (\`"EDC eCRF"\`, \`"Protocol Deviation"\`, \`"EDC Query"\`,
\`"EDC PD"\`), \`record_id\`, \`record_date\` and the source's key
fields as further columns. Fills the listing's expanded rows and the CSV
details columns (pilot mode). 3. \*\*Status history\*\*:
\`dfStatusHistory\`, the rows of \[elig_StatusCounts()\] that the study
saves every snapshot, with \`SnapshotDate\`. Adds the Status over Time
tab (pilot mode).

Site-level rows of \`dfGroups\` (\`InvestigatorFirstName\`,
\`InvestigatorLastName\`) fill the listing's Investigator Name; with
Study-level groups only, the column is blank.

## Examples

``` r
if (FALSE) { # \dontrun{
dfResults <- gsm.core::reportingResults_study %>%
  dplyr::filter(MetricID == "Analysis_qtl0001")
dfMetrics <- gsm.core::reportingMetrics_study %>%
  dplyr::filter(MetricID == "Analysis_qtl0001")

mappings_wf <- workr::MakeWorkflowList(
  strNames = c("IE", "EXCLUSION", "ENROLL", "PD"),
  strPath = "workflow/1_mappings",
  strPackage = "gsm.mapping"
)
lRaw <- gsm.mapping::Ingest(gsm.core::lSource, gsm.mapping::CombineSpecs(mappings_wf))
mapped <- workr::RunWorkflows(mappings_wf, lRaw)

Report_Eligibility(
  dfResults = dfResults,
  dfMetrics = dfMetrics,
  dfGroups = gsm.core::reportingGroups,
  lListings = list(
    IE_num = dplyr::filter(mapped$Mapped_EXCLUSION, Source != "Neither"),
    IE_denom = mapped$Mapped_EXCLUSION
  ),
  strOutputDir = tempdir()
)
} # }
```
