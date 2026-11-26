# Ineligibility listing CSV data

\`r lifecycle::badge("experimental")\`

The listing plus one \`"\<source\> details"\` column per source: each
record's \`Field: value\` pairs joined by \`"; "\`, records joined by
\`" \| "\`. One line per cell, because Excel's text import splits rows
at line breaks even inside quotes.

## Usage

``` r
elig_ExportData(
  dfListing,
  dfPartRecords,
  bRecords = TRUE,
  lSetup = elig_Setup()
)
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

- lSetup:

  \`list\` from \[elig_Setup()\].

## Value

\`data.frame\`.
