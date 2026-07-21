# Make Chart Config

Helper function to create chart configuration for a specific metric and
chart type.

## Usage

``` r
MakeChartConfig(lMetric, strChartFunction, ...)
```

## Arguments

- lMetric:

  \`list\` Metric-specific metadata for use in charts and reporting.
  Created by passing an \`lWorkflow\` object to \[MakeMetric()\] and
  turing it into a list. Expected columns: \`File\`,\`MetricID\`,
  \`Group\`, \`Abbreviation\`, \`Metric\`, \`Numerator\`,
  \`Denominator\`, \`Model\`, \`Score\`, and \`strThreshold\`. For more
  details see the Data Model vignette: \`vignette("DataModel", package =
  "gsm.kri")\`.

- strChartFunction:

  \`character\` Name of chart function.

- ...:

  \`any\` Additional chart configuration settings.

## Value

\`list\` Chart configuration.
