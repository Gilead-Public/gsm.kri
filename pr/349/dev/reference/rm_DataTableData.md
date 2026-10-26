# Data table rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The two shapes of the Data table (§5). Participants follow the
Participant Listing order: worst flag, then most repeating windows, then
participant.

\* \`rm_DataTableData()\` (Long): one row per participant, vital and
non-missing value, in measurement order. \`has_repeat\` marks the
participant's vitals with at least one repeat window. \*
\`rm_DataTableWide()\` (Wide): one row per \`Mapped_VS\` record with one
column per vital (blank when not measured) and a
\`\<vital\>\_in_repeat_window\` column (\`"Y"\`, \`"N"\` or \`""\`) per
vital. \`repeat_vitals\` lists the participant's vitals with at least
one repeat window.

## Usage

``` r
rm_DataTableData(lClass)

rm_DataTableWide(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`tibble\`. Long: \`country\`, \`invid\`, \`subjid\`, \`label\`,
\`metric\`, \`seq\`, \`visit\`, \`vs_dt\`, \`value\`,
\`in_repeat_window\` (\`"Yes"\`/\`"No"\`), and the hidden \`vital\` and
\`has_repeat\` columns. Wide: \`country\`, \`invid\`, \`subjid\`,
\`visit\`, \`vs_dt\`, \`performed\` (\`"Y"\`/\`"N"\`), one column per
vital, one \`\<vital\>\_in_repeat_window\` column per vital and the
hidden \`repeat_vitals\` column.
