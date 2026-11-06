# Data table for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The Wide \`DT\` table of the Data table, \`rm-dt-wide\`. Values in a
repeating window are dark red. To fit without horizontal scrolling, it
abbreviates the measure headers (name and metric on hover), shows the
country on hover over the site and greys the records not performed; the
CSV keeps the full headers and the country and performed columns. Every
column is named so the report's filter script can find it: the script
filters \`country\`, \`invid\`, \`subjid\` and \`repeat_vitals\`, hides
the measure columns that are not selected, turns a row click into the
participant filter and builds the Long table from these rows. The CSV
holds the rows the filters show, with the shown measures and their
\`\<vital\>\_in_repeat_window\` columns.

## Usage

``` r
rm_DataTable(dfWide, dfVitals, bExport = TRUE)
```

## Arguments

- dfWide:

  \`data.frame\` Output of \[rm_DataTableWide()\].

- dfVitals:

  \`data.frame\` \`vitals\` from \[rm_Classify()\].

- bExport:

  \`logical\` Show the CSV button.

## Value

A \`DT\` htmlwidget.
