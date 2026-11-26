# Eligibility flag names

\`r lifecycle::badge("experimental")\`

Looks up a \`dfSources\` column for flags.

## Usage

``` r
elig_FlagLabel(vFlags, lSetup = elig_Setup(), strColumn = "label")
```

## Arguments

- vFlags:

  \`character\` Flag column names.

- lSetup:

  \`list\` Result of \[elig_Setup()\].

- strColumn:

  \`character\` \`dfSources\` column to return. Default: \`"label"\`.

## Value

Unnamed \`character\`, one value per flag.
