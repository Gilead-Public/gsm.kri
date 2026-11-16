# Criterion slices (criteria view A)

Criterion slices (criteria view A)

## Usage

``` r
elig_CriteriaRows(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`list\` from \[elig_BreakdownRows()\], keyed by criterion code and
filled by Inclusion / Exclusion. Each scope holds only the criteria with
cases in it.
