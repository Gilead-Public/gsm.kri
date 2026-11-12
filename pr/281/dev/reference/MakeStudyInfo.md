# Generate a study information data.frame for use in reports

\`r lifecycle::badge("stable")\`

Generate a study info table summarizing study metadata.

## Usage

``` r
MakeStudyInfo(dfGroups, lStudyLabels = NULL, lStudy = deprecated())
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lStudyLabels:

  \`list\` A list containing study labels. Default is NULL.

- lStudy:

  \`deprecated\` Study information as a named list.

## Value

A data.frame containing study metadata.

## Examples

``` r
MakeStudyInfo(gsm.core::reportingGroups)
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
MakeStudyInfo(gsm.core::reportingGroups, list(SiteCount = "# Sites"))
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
```
