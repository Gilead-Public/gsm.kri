# Stack Analysis Outputs

Stack Analysis Outputs

## Usage

``` r
StackAnalysis(lAnalysis, strName = "Analysis_Flagged")
```

## Arguments

- lAnalysis:

  \`list\` List of analysis outputs from the metrics calculated in the
  \`workflow/2_metrics\` workflows. May be filtered via
  \`FilterAnalysis()\`

- strName:

  \`character\` Name of the analysis output data.frame to stack. Default
  is "Analysis_Flagged".

## Value

\`data.frame\` Stacked analysis outputs from the metrics calculated in
the \`workflow/2_metrics\` workflows.

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
dfFlaggedWeights <- StackAnalysis(lAnalysis_filtered)
```
