# Add group meta data for report

Add group meta data for report

## Usage

``` r
add_Groups_metadata(
  dfResults,
  dfGroups,
  strGroupLevel = c("Site", "Study", "Country"),
  strGroupDetailsParams
)
```

## Arguments

- dfResults:

  \`data.frame\` Analysis results data.

- dfGroups:

  \`data.frame\` Analysis groups data.

- strGroupLevel:

  \`string\` denoting group level

- strGroupDetailsParams:

  \`string\`

## Value

A modified \`dfResults\` which metadata attached
