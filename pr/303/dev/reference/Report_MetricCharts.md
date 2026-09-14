# Render charts for a given metric to markdown

\`r lifecycle::badge("stable")\`

This function generates a markdown framework for charts

## Usage

``` r
Report_MetricCharts(lCharts, strMetricID = "")
```

## Arguments

- lCharts:

  A list of charts for the selected metric.

- strMetricID:

  \`character\` Metric ID, wich is added as a class to each rendered
  chart to uniquely identify it within the report.

## Value

Markdown content with charts and a summary table for the metric
