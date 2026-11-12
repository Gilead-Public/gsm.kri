# Filter by Latest Snapshot Date

Filter a data frame to the most recent snapshot date.

## Usage

``` r
FilterByLatestSnapshotDate(df, strSnapshotDate = NULL)
```

## Arguments

- df:

  A data frame containing the results.

- strSnapshotDate:

  A character string representing the snapshot date.

## Value

A data frame containing the results for the most recent snapshot date.

## Examples

``` r
reportingResults_latest <- FilterByLatestSnapshotDate(gsm.core::reportingResults)
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
```
