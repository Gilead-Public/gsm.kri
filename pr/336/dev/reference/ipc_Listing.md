# Participant listing table for the IP Compliance report

\`r lifecycle::badge("experimental")\`

A \`DT\` table with a search box and a CSV button. The report's filter
script searches the named \`dosed\`, \`country\` and \`invid\` columns.
The CSV holds every participant whatever the filters and search.

## Usage

``` r
ipc_Listing(dfListing)
```

## Arguments

- dfListing:

  \`data.frame\` Output of \[ipc_ListingData()\].

## Value

A \`DT\` htmlwidget with element id \`ipc-listing\`.
