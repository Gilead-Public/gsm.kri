# Criteria map rows (criteria view B)

Participants per group and criterion, for the country and site maps.
Only groups with at least one criterion case appear; the report hides
criteria with no case among the rows shown.

## Usage

``` r
elig_CriteriaMapRows(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`list\` with \`order\` (criteria), \`country\` and \`site\` rows
(\`GroupID\`, \`OuterGroupID\`, \`criterion\`, \`n\`).
