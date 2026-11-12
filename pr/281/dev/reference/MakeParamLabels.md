# Create Labels for Parameters

\`r lifecycle::badge("stable")\`

Convert a vector of parameters to labels in Title Case.
\`MakeParamLabels\` adds a \`Labels\` column to a \`data.frame\` that
has a \`Params\` column (such as \`dfGroups\`), while
\`MakeParamLabelsList\` returns just the list of named parameters.

## Usage

``` r
MakeParamLabels(dfGroups, lParamLabels = NULL)

MakeParamLabelsList(chrParams, lParamLabels = NULL)
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lParamLabels:

  \`list\` Labels for parameters, with the parameters as names, and the
  label as value.

- chrParams:

  A character vector of parameters, or a list that can be coerced to a
  character vector.

## Value

\`dfGroups\` with an added \`Label\` column, or a list of labeled
parameters.

## Examples

``` r
head(gsm.core::reportingGroups)
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
MakeParamLabels(head(gsm.core::reportingGroups))
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
MakeParamLabels(
  head(gsm.core::reportingGroups),
  list(ParticipantCount = "Number of Participants")
)
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
MakeParamLabelsList(head(gsm.core::reportingGroups$Param))
#> Error in .testdata_abort_no_match(pkg, version, sha): No published gsm test data matches gsm.mapping 1.2.0 (de2868c) together
#> with your other installed gsm packages.
#> ℹ gsm.mapping is probably out of step with the other gsm packages. Updating it
#>   (or them) to a compatible set usually fixes this.
#> ℹ To use specific data anyway, see `use_testdata_tag()` or
#>   `use_testdata_snapshot()`.
```
