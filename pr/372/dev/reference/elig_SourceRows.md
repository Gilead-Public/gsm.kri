# Flag source slices

One bar per delivered source counting the participants it flagged,
stacked by their overall status (Ineligible wins). A participant counts
under every source that flagged them.

## Usage

``` r
elig_SourceRows(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`list\` from \[elig_BreakdownRows()\].
