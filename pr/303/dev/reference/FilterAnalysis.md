# Filter Analysis Outputs

Filter Analysis Outputs

## Usage

``` r
FilterAnalysis(lAnalysis, strFilterIDPattern = "kri")
```

## Arguments

- lAnalysis:

  \`list\` List of analysis outputs from the metrics calculated in the
  \`workflow/2_metrics\` workflows.

- strFilterIDPattern:

  \`character\` Pattern to filter the analysis IDs. Default is "kri".

## Value

\`list\` Filtered list of analysis outputs from the metrics calculated
in the \`workflow/2_metrics\` workflows.

## Examples

``` r
analysisFlagged <- gsm.core::analyticsSummary %>%
  dplyr::mutate(
    Weight = dplyr::case_when(
      abs(Flag) == 1 ~ 2,
      abs(Flag) == 2 ~ 4,
      Flag == 0 ~ 0,
      TRUE ~ NA
    ),
    WeightMax = 4
  )
lAnalysis <- list("Analysis_kri0001" = list(
  Analysis_Flagged = analysisFlagged,
  ID = "Analysis_kri0001"
))
lAnalysis_filtered <- FilterAnalysis(lAnalysis)
```
