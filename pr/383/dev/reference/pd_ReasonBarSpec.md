# Serializable gsm.viz \`bars\` spec for the reason distribution chart

\`r lifecycle::badge("experimental")\`

Horizontal single-series bars, each carrying its count on the bar when
the bar is long enough to hold the label. Ready to hand to
\[gsm.vizr::bars()\]; the tooltip formatter is attached here as a
\`js_hook\`.

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
