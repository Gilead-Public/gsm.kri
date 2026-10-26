# Vitals listing rows for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The vitals listing (§4): one row per participant and vital, for every
vital in \`Mapped_VS\`, with the measurements in order. \`values\` and
\`in_repeat_window\` are space-separated and aligned: \`"72 72 72 80"\`
and \`"1 1 1 0"\`.

## Usage

``` r
rm_VitalRows(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`tibble\` in display order (worst flag, then most repeat windows)
with \`country\`, \`invid\`, \`subjid\`, \`label\`, \`metric\`,
\`flag\`, \`measured\`, \`Numerator\`, \`Denominator\`, \`rate\`,
\`values\`, \`in_repeat_window\`, and the hidden \`vital\` and
\`has_repeat\` columns.
