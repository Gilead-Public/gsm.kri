# Filter out non-flagged rows on FlagOverTime Widget

Filter a results dataframe so that only metrics across all timepoints
that have at least one flag are kept

## Usage

``` r
FilterByFlags(dfResults, bCurrentlyFlagged = FALSE)
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results data.

- bCurrentlyFlagged:

  \`logical\` Include risk signals flagged in most recent snapshot?
  Default: \`FALSE\`.

## Value

A data frame containing the results with at least one flagged record
over time for an group's individual metric

## Examples

``` r
reportingResults_flags <- FilterByFlags(gsm.core::reportingResults)
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
```
