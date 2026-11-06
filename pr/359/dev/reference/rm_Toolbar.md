# Filter strip of the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The sticky bar under the header: the measure picker, the country, site
and participant filter chips, Reset filters, and the Settings popover,
which \`rmFilters.js\` fills from the settings in \`#rm-data\`.

## Usage

``` r
rm_Toolbar(dfVitals, lSettings)
```

## Arguments

- dfVitals:

  \`data.frame\` The measures, \`vitals\` of \[rm_Classify()\].

- lSettings:

  \`list\` The initial settings: \`rule\`, \`thresholds\`,
  \`minWindows\` and \`bp\`.

## Value

An \`htmltools\` tag.
