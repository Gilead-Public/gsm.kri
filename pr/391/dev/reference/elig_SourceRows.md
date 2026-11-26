# Flag source slices

One bar per delivered source that flagged a participant in scope,
counting the participants it flagged, stacked by their overall status
(Ineligible wins). A participant counts under every source that flagged
them.

## Usage

``` r
elig_SourceRows(dfElig, lSetup = elig_Setup())
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- lSetup:

  \`list\` from \[elig_Setup()\].

## Value

\`list\` from \[elig_BreakdownRows()\].
