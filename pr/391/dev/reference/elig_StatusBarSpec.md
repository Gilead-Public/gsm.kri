# Eligibility status bar chart specification

\`r lifecycle::badge("experimental")\`

100

## Usage

``` r
elig_StatusBarSpec(
  strLevel = c("study", "country", "site"),
  vOrder = NULL,
  bPilot = FALSE
)
```

## Arguments

- strLevel:

  \`character\` One of \`"study"\`, \`"country"\` or \`"site"\`.

- vOrder:

  \`character\` Group order, or \`NULL\`.

- bPilot:

  \`logical\` Three statuses (pilot mode) or two.

## Value

\`list\` chart specification for \`gsm.vizr::bars()\`.
