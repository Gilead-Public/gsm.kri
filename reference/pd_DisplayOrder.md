# Premature-death bucket stacking order

Bottom-to-top stacking order for the bucket bars: best outcome at the
base (alive at the window), worst at the top (death within 30 days).
This is a \*display\* reordering only and is deliberately distinct from
\[pd_CategoryLevels()\], which stays in precedence order so
classification, colors, and the cross-filter keep working unchanged.

## Usage

``` r
pd_DisplayOrder(nWindowDays)
```

## Arguments

- nWindowDays:

  \`numeric\` Premature-death window in days.

## Value

A length-5 \`character\` vector: a reordering of
\[pd_CategoryLevels()\].
