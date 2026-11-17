# Criteria site spread slices (criteria view C)

One row per criterion: participants, sites and countries, with the
per-site counts behind them; for the study, each country and each
country's sites. Criteria with the most participants at one site come
first (then the largest share), so a site problem stands out from a
protocol-wide one.

## Usage

``` r
elig_SiteSpreadRows(dfElig)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

## Value

\`list\` with \`study\`, \`country\` and \`site\` (by country, then
site) slices; each slice is a \`tibble\` with one row per criterion and
the per-site counts, largest first, in the \`by_site\` list column.
