# Ineligibility listing CSV data

\`r lifecycle::badge("experimental")\`

The listing plus one \`"\<source\> details"\` column per source: each
record as one \`Field: value\` per line, a blank line between records.

## Usage

``` r
elig_ExportData(dfListing, dfPartRecords, bRecords = TRUE)
```

## Arguments

- dfListing:

  \`data.frame\` from \[elig_ListingData()\].

- dfPartRecords:

  \`data.frame\` from \[elig_ParticipantRecords()\].

- bRecords:

  \`logical\` Level 2 records delivered. Without them only Protocol
  Deviation gets a details column: eCRF details would only repeat Which
  I/E.

## Value

\`data.frame\`.
