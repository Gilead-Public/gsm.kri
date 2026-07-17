# Premature-death category colors

Named color vector keyed by \[pd_CategoryLevels()\]: red/amber (deaths),
dark-grey (discontinuation), dark green (alive at window), light green
(alive prior to window). Reuses \[colorScheme()\] so no new hues are
introduced.

## Usage

``` r
pd_CategoryColors(nWindowDays)
```

## Arguments

- nWindowDays:

  \`numeric\` Premature-death window in days.

## Value

A length-5 named \`character\` vector of hex colors.
