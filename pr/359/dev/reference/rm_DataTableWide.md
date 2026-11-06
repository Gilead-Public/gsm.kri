# Data table rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The Wide data table: one row per \`Mapped_VS\` record with one column
per measure (blank when not measured) and a
\`\<vital\>\_in_repeat_window\` column (\`"Y"\`, \`"N"\` or \`""\`) per
measure. \`repeat_vitals\` lists the participant's measures with at
least one repeating window. Participants follow the Participant listing
order (worst flag, then most repeating windows, then participant); each
participant's records are in measurement order (date, visit, record).
The report builds the Long table in the browser from these rows, so the
data are embedded once.

## Usage

``` r
rm_DataTableWide(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`tibble\` with \`country\`, \`invid\`, \`subjid\`, \`visit\`,
\`vs_dt\`, \`performed\` (\`"Y"\`/\`"N"\`), one column per measure, one
\`\<vital\>\_in_repeat_window\` column per measure and the hidden
\`repeat_vitals\` column.
