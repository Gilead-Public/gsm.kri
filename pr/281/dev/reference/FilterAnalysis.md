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
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
lAnalysis <- list("Analysis_kri0001" = list(
  Analysis_Flagged = analysisFlagged,
  ID = "Analysis_kri0001"
))
#> Error: object 'analysisFlagged' not found
lAnalysis_filtered <- FilterAnalysis(lAnalysis)
#> Error: object 'lAnalysis' not found
```
