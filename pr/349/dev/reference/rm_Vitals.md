# Vital signs known to the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The six vitals scored by \`kri0020a\`–\`f\` / \`cou0020a\`–\`f\`, then
height and BSA, which are listed without a flag.

## Usage

``` r
rm_Vitals()
```

## Value

A \`tibble\` with \`vital\` (the \`Mapped_VS\` column), \`label\`,
\`short\`, \`group\` (the report's vital filter; \`NA\` without a KRI)
and \`metric\` (the site workflow ID; \`NA\` without a KRI).
