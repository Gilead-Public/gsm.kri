# Eligibility report mode

\`r lifecycle::badge("experimental")\`

The study picks the mode with \`strMode\`. Pilot mode falls back to
basic, with a warning, when neither \`edc_query\` nor \`edc_pd\` has
data: a pilot report with no EDC source would show only N/A columns.

## Usage

``` r
elig_Mode(dfExclusion, strMode = c("basic", "pilot"))
```

## Arguments

- dfExclusion:

  \`data.frame\` \`Mapped_EXCLUSION\`.

- strMode:

  \`character\` \`"basic"\` (default) or \`"pilot"\`.

## Value

\`character\` \`"basic"\` or \`"pilot"\`.
