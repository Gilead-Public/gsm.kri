# Serializable gsm.viz \`bars\` spec for the premature-death bucket chart

The data-driven half of the spec (mapping, orientation, position, stat,
scales, legend, value labels). Non-serializable pieces (tooltip
formatter, click/hover callbacks) are attached in
\`Widget_PrematureDeathBucketBar.js\`.

Each segment carries its value on the bar: counts in the stack and dodge
views, percentages in the native fill (100

## Usage

``` r
pd_BucketBarSpec(nWindowDays = 90, strGroupLabel = "Group", zoom = NULL)
```

## Arguments

- nWindowDays:

  \`numeric\` Window in days (color/order vocabulary).

- strGroupLabel:

  \`character\` Category-axis label.

- zoom:

  \`list\` or \`NULL\` Optional \`gsm.viz\` zoom spec (e.g.
  \`list(enabled = TRUE, mode = "x")\`). Attached only when
  non-\`NULL\`; the site chart opts in so its many bars can be zoomed,
  the study/country charts do not. Default \`NULL\` (no zoom).

## Value

A named \`list\` — a \`gsm.viz\` \`bars\` spec without callbacks.
