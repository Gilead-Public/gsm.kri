# Serializable gsm.viz \`bars\` spec for the reason distribution chart

\`r lifecycle::badge("experimental")\`

Horizontal single-series bars. The tooltip formatter and callbacks are
attached in \`Widget_PrematureDeathReasonBar.js\`; this returns only the
serializable spec.

## Usage

``` r
pd_ReasonBarSpec(reason_order = NULL)
```

## Arguments

- reason_order:

  \`character\` or \`NULL\`. Explicit category order for the reasons.
  gsm.viz orders categories alphanumerically unless \`scales\$x\$order\`
  is set (\`sort\`/\`sortDir\` only pick the top-N when \`nCategories\`
  is capped, which this chart does not use). Pass the reasons in count
  order to keep the count sort the former Plotly chart got from
  \`stats::reorder(reason, n)\`. \`NULL\` (default) leaves the axis
  alphanumeric.

## Value

A named \`list\` — a \`gsm.viz\` \`bars\` spec without callbacks.
