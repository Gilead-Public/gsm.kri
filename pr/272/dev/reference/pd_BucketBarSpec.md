# Serializable gsm.viz \`bars\` spec for the premature-death bucket chart

The data-driven half of the spec (mapping, orientation, position, stat,
scales, legend). Non-serializable pieces (tooltip formatter, click/hover
callbacks) are attached in \`Widget_PrematureDeathBucketBar.js\`.

## Usage

``` r
pd_BucketBarSpec(nWindowDays = 90, strGroupLabel = "Group")
```

## Arguments

- nWindowDays:

  \`numeric\` Window in days (color/order vocabulary).

- strGroupLabel:

  \`character\` Category-axis label.

## Value

A named \`list\` — a \`gsm.viz\` \`bars\` spec without callbacks.
