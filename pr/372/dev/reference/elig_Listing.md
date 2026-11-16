# Ineligibility listing

\`r lifecycle::badge("experimental")\`

Expanding a row shows the participant's level 2 records when delivered,
otherwise the PD dates/terms and criterion codes of
\`Mapped_EXCLUSION\`.

## Usage

``` r
elig_Listing(dfListing, dfElig, dfRecords = NULL, strID = "elig-listing")
```

## Arguments

- dfListing:

  \`data.frame\` from \[elig_ListingData()\].

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- dfRecords:

  \`data.frame\` Level 2 records, or \`NULL\`.

- strID:

  \`character\` Element ID.

## Value

\`reactable\` widget.
