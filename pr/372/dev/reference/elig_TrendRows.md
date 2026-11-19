# Status over time rows

One bar per snapshot that has both the rate metric (qtl0001) and the
level 3 risk metric: Ineligible = qtl0001 numerator; Potentially
Ineligible = risk numerator - qtl0001 numerator; No Eligibility Risk =
denominator - risk numerator.

## Usage

``` r
elig_TrendRows(dfResults)
```

## Arguments

- dfResults:

  \`data.frame\` Reporting results.

## Value

\`tibble\` with \`GroupID\` (snapshot date), \`Status\` and \`n\`.
