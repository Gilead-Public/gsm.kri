# Premature-death bucket bar widget (gsm.viz)

\`r lifecycle::badge("experimental")\`

htmlwidget wrapper that renders premature-death category counts via a
flat \`gsm.viz\` \`bars\` chart (one per study/country/site view).
Serializes long rows from \[pd_BucketRows()\] plus the serializable spec
from \[pd_BucketBarSpec()\]; the widget JS attaches the tooltip
formatter and click/hover callbacks.

## Usage

``` r
Widget_PrematureDeathBucketBar(data, spec, metadata = list(), bDebug = FALSE)
```

## Arguments

- data:

  \`data.frame\` Long rows from \[pd_BucketRows()\].

- spec:

  \`list\` Serializable \`bars\` spec from \[pd_BucketBarSpec()\].

- metadata:

  \`list\` Report keys (\`chartId\`, \`level\`, ...) for linked
  filtering.

- bDebug:

  \`logical\` Log the serialized input to the browser console. Default
  \`FALSE\`.

## Value

A \`Widget_PrematureDeathBucketBar\` htmlwidget.
