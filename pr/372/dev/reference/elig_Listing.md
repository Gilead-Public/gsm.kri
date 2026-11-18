# Ineligibility listing

\`r lifecycle::badge("experimental")\`

Expanding a row shows the records behind the participant's status, one
table per source.

## Usage

``` r
elig_Listing(dfListing, dfPartRecords, strID = "elig-listing")
```

## Arguments

- dfListing:

  \`data.frame\` from \[elig_ListingData()\].

- dfPartRecords:

  \`data.frame\` from \[elig_ParticipantRecords()\].

- strID:

  \`character\` Element ID.

## Value

\`reactable\` widget.
