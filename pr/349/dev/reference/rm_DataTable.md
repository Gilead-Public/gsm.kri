# Data table for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The two \`DT\` tables of the Data table (§5): \`rm-dt-long\` and
\`rm-dt-wide\`. Values in a repeat window are red. To fit without
horizontal scrolling, Long shows the metric as a KRI badge on the vital
(metric ID on hover); Wide abbreviates the vital headers (name and
metric on hover), shows the country on hover over the site and greys the
records not performed. The CSVs keep the full headers and the country,
metric and performed columns. The report's filter script switches
between them, filters the named \`vital\`, \`country\`, \`invid\`,
\`subjid\`, \`has_repeat\` and \`repeat_vitals\` columns, hides the Wide
vital columns outside the selected group, and turns a row click into the
participant filter. Each CSV holds the rows the filters show: Long with
every column, Wide with the shown vitals and their
\`\<vital\>\_in_repeat_window\` columns.

## Usage

``` r
rm_DataTable(dfLong, dfWide, dfVitals, bExport = TRUE)
```

## Arguments

- dfLong:

  \`data.frame\` Output of \[rm_DataTableData()\].

- dfWide:

  \`data.frame\` Output of \[rm_DataTableWide()\].

- dfVitals:

  \`data.frame\` \`vitals\` from \[rm_Classify()\].

- bExport:

  \`logical\` Show the CSV buttons.

## Value

A named \`list\` of two \`DT\` htmlwidgets, \`long\` and \`wide\`.
