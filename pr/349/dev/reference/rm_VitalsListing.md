# Vitals listing tables for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Two \`DT\` tables. \`rm-vitals\` (level 1) draws the measurements in
order with repeat-window values highlighted; the report's filter script
toggles the numbers and filters the named \`vital\`, \`country\`,
\`invid\`, \`subjid\` and \`has_repeat\` columns. \`rm-records\` (level
2) highlights each record's repeat-window cells. The CSV of each holds
the rows the filters show.

## Usage

``` r
rm_VitalsListing(dfVitalRows, dfRecordRows, dfVitals, bExport = TRUE)
```

## Arguments

- dfVitalRows:

  \`data.frame\` Output of \[rm_VitalRows()\].

- dfRecordRows:

  \`data.frame\` Output of \[rm_RecordRows()\].

- dfVitals:

  \`data.frame\` \`vitals\` from \[rm_Classify()\].

- bExport:

  \`logical\` Show the CSV buttons.

## Value

A named \`list\` of two \`DT\` htmlwidgets, \`vitals\` and \`records\`.
