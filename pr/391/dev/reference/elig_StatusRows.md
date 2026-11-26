# Eligibility status bar rows

\`r lifecycle::badge("experimental")\`

One row per group and status with a non-zero count. Sites are in natural
alphanumeric order; study and country groups lead with the highest
Ineligible share, then any-risk share, then size.

## Usage

``` r
elig_StatusRows(dfElig, strLevel = c("study", "country", "site"))
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- strLevel:

  \`character\` One of \`"study"\`, \`"country"\` or \`"site"\`.

## Value

\`tibble\` with \`GroupID\`, \`OuterGroupID\`, \`Status\`, \`n\` and
\`Level\`.
