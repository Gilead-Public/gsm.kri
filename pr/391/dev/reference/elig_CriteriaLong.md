# Criterion cases

Criterion cases

## Usage

``` r
elig_CriteriaLong(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`tibble\` with one row per participant and EDC I/E criterion code:
\`subjid\`, \`country\`, \`invid\`, \`status\`, \`criterion\` and
\`type\`. A participant whose \`criteria_type\` does not pair one to one
with the codes is Not classified.
