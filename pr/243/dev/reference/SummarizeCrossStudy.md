# Summarize Cross-Study Risk Scores

\`r lifecycle::badge("experimental")\`

Creates a summary table showing cross-study site risk score metrics
including number of studies, average and maximum risk scores, and
investigator names.

## Usage

``` r
SummarizeCrossStudy(
  dfResults,
  strGroupLevel = "Site",
  dfGroups = NULL,
  strNameCol = "InvestigatorLastName"
)
```

## Arguments

- dfResults:

  \`data.frame\` A data frame containing results from multiple studies.

- strGroupLevel:

  \`character\` The group level to summarize. Default is 'Site'.

- dfGroups:

  \`data.frame\` Optional. A data frame containing group metadata (for
  InvestigatorName lookup). Must include StudyID, GroupID, Param, and
  Value columns.

- strNameCol:

  \`character\` The column name in dfGroups to use for investigator
  names. Default is 'InvestigatorLastName'.

## Value

\`data.frame\` Summary table with the following columns: - GroupID: Site
identifier - NumStudies: Number of studies the site participates in -
AvgRiskScore: Average site risk score across studies - MaxRiskScore:
Maximum site risk score across studies - InvestigatorName: Investigator
name (if dfGroups provided)

## Examples

``` r
if (FALSE) { # \dontrun{
# See https://gilead-biostats.github.io/gsm.kri/examples/Example_CrossStudySRS.html
} # }
```
