# Site KRI flags for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The site-level \`kri0020a\`–\`f\` flags from each metric's latest
snapshot, keyed by vital. A site without a flag in that snapshot is
\`NA\` (not evaluated).

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
