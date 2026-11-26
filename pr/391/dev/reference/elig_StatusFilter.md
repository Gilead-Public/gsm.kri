# Show filter above the country or site status chart

\`r lifecycle::badge("experimental")\`

Buttons keep only the groups with at least one participant in the given
statuses; their bars keep every status. Each button carries its statuses
as JSON, so the report's JavaScript holds no status names.

## Usage

``` r
elig_StatusFilter(strLevel = c("country", "site"), bPilot = FALSE)
```

## Arguments

- strLevel:

  \`character\` One of \`"country"\` or \`"site"\`.

- bPilot:

  \`logical\` Offer "With any risk" (pilot mode).

## Value

\`htmltools\` tag.
