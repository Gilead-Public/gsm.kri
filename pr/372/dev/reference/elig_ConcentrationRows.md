# Criteria concentration slices (criteria view C)

One row per criterion: participants, sites, countries and the site with
the most cases, with the per-site counts behind it; for the study, each
country and each country's sites.

## Usage

``` r
elig_ConcentrationRows(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`list\` with \`study\`, \`country\` and \`site\` (by country, then
site) slices; each slice is a \`tibble\` with one row per criterion and
the per-site counts in the \`by_site\` list column.
