# Measure listing table for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The \`rm-vitals\` \`DT\` table: one row per participant and measure with
the measure name (metric ID on hover, \`\*\` for a measure with no KRI),
the distinct / non-missing values, a single "Flag and rate" column
(measured, N and D on hover; sorts by flag, then rate) and the
measurements in order with values in a repeating window highlighted and
each value's position, visit and date on hover. The report's filter
script toggles the numbers, filters the named \`vital\`, \`country\`,
\`invid\`, \`subjid\` and \`has_repeat\` columns, and turns a row click
into the participant filter. The CSV holds the rows the filters show
with every column, including the metric, flag, measured, N, D, rate and
visits. The filter script also rewrites the flag column when the
reviewer changes the flag rule.

## Usage

``` r
rep_VitalsListing(dfVitalRows, nWindowLength = NULL, bExport = TRUE)
```

## Arguments

- dfVitalRows:

  \`data.frame\` Output of \[rep_VitalRows()\].

- nWindowLength:

  \`numeric\` Window length, shown in the measurements header. Optional.

- bExport:

  \`logical\` Show the CSV button.

## Value

A \`DT\` htmlwidget.
