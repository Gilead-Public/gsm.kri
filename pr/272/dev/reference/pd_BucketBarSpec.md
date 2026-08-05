# Serializable gsm.viz \`bars\` spec for the premature-death bucket chart

The data-driven half of the spec (mapping, orientation, position, stat,
scales, legend, value labels). Non-serializable pieces (tooltip
formatter, click/hover callbacks) are attached in
\`Widget_PrematureDeathBucketBar.js\`.

Each segment carries its value on the bar: counts in the stack and dodge
views, percentages in the native fill (100

## Usage

``` r
pd_BucketBarSpec(
  nWindowDays = 90,
  strGroupLabel = "Group",
  zoom = NULL,
  theme = NULL
)
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
  the study/country charts do not. Enabling it also captions the chart
  with the scroll-to-zoom affordance. Default \`NULL\` (no zoom).

- theme:

  \`list\` or \`NULL\` Optional \`gsm.viz\` theme spec, passed through
  untouched (e.g. \`list(dynamicCategoryAxis = TRUE)\`, which drops
  categories off the axis once a disabled legend entry leaves them empty
  — the site chart opts in so hiding a death window thins its many
  bars). Omitted when \`NULL\`, leaving gsm.viz's own theme defaults in
  place. Default \`NULL\`.

## Value

A named \`list\` — a \`gsm.viz\` \`bars\` spec without callbacks.
