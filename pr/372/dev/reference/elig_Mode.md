# Eligibility report mode

\`r lifecycle::badge("experimental")\`

\`"pilot"\` when \`Mapped_EXCLUSION\` carries the optional \`edc_query\`
flag column (data contract level 1), otherwise \`"basic"\`.

## Usage

``` r
elig_Mode(dfExclusion)
```

## Arguments

- dfExclusion:

  \`data.frame\` \`Mapped_EXCLUSION\`.

## Value

\`character\` \`"basic"\` or \`"pilot"\`.
