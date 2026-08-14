# Premature-death reason bar widget (gsm.viz)

\`r lifecycle::badge("experimental")\`

htmlwidget wrapper rendering the horizontal reason-distribution bar via
\`gsm.viz\` \`bars\`. Serializes long rows from \[pd_ReasonRows()\] plus
the serializable spec from \[pd_ReasonBarSpec()\]; the widget JS
attaches the tooltip formatter. When \`metadata\` carries a \`reactive\`
map of per-country row frames, the widget swaps its data via
\`helpers.updateData\` on the \`pdBucketFilterChanged\` event so a
country click reshapes the reason bar without a second spec definition.

## Usage

``` r
Widget_PrematureDeathReasonBar(data, spec, metadata = list(), bDebug = FALSE)
```

## Arguments

- data:

  \`data.frame\` Rows from \[pd_ReasonRows()\] (the initial
  \`\_\_ALL\_\_\` slice).

- spec:

  \`list\` Serializable spec from \[pd_ReasonBarSpec()\].

- metadata:

  \`list\` Report keys (\`chartId\`, \`level\`, ...); may include
  \`reactive\`, a named list of per-country row \`data.frame\`s keyed by
  country plus \`\_\_ALL\_\_\`.

- bDebug:

  \`logical\` Log the serialized input to the browser console. Default
  \`FALSE\`.

## Value

A \`Widget_PrematureDeathReasonBar\` htmlwidget.
