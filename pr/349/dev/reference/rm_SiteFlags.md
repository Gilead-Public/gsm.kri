# Site KRI flags for the Repeat Measurements distribution charts

\`r lifecycle::badge("experimental")\`

The latest site-level \`kri0020a\`–\`f\` flag per site, keyed by vital.

## Usage

``` r
rm_SiteFlags(dfResults)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results.

## Value

A named \`list\` (vital to a named list of site flags); empty when
\`dfResults\` has no \`kri0020\` site results.
