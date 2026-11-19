# Flag sources shown by the report

Flag sources shown by the report

## Usage

``` r
elig_Sources(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

Named \`character\`: flag column = display name, in display order. The
PD split replaces the single PD source when delivered, unless a PD is
neither important nor non-important; EDC Query and EDC PD stay listed
when not delivered, so the listing can show "N/A".
