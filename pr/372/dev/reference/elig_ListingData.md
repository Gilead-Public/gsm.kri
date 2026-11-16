# Ineligibility listing data

\`r lifecycle::badge("experimental")\`

Flagged participants only (Ineligible first). Flag columns are Y/N; EDC
PD is \`"N/A"\` when the source is not delivered. PD dates and terms
spread into \`PD Date 1..n\` / \`PD Term 1..n\`.

## Usage

``` r
elig_ListingData(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`data.frame\`.
