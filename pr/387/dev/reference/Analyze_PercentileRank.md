# Score groups by percentile rank

\`r lifecycle::badge("experimental")\`

Ranks groups on \`strValueCol\` (highest first) and scores each group as
\`100 \* (n - r) / n\`, where \`n\` is the number of ranked groups and
\`r\` is the group's competition rank (1 + the number of groups with a
strictly higher value). Tied groups share the better rank. With
thresholds \`c(80, 90)\` and \`gsm.core::Flag()\`'s \`\[a, b)\`
intervals, the top 10 and the next 10 and get a missing \`Score\`.

## Usage

``` r
Analyze_PercentileRank(dfTransformed, strValueCol = "Numerator")
```

## Arguments

- dfTransformed:

  \`data.frame\` One row per group, e.g. from
  \`gsm.core::Transform_Rate()\`.

- strValueCol:

  \`character\` Column to rank on. Default \`"Numerator"\`.

## Value

\`dfTransformed\` with a \`Score\` column (0-100), sorted by \`Score\`.

## Examples

``` r
df <- data.frame(GroupID = LETTERS[1:5], Numerator = c(40, 25, 25, 10, 0))
Analyze_PercentileRank(df)
#>   GroupID Numerator Score
#> 5       E         0     0
#> 4       D        10    20
#> 2       B        25    60
#> 3       C        25    60
#> 1       A        40    80
```
