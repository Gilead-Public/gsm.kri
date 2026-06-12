# gsm.kri

<!-- badges: start -->

<div class="pkgdown-release">

[![R-CMD-check](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/R-CMD-check.yaml/badge.svg?branch=main)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/test-coverage.yaml/badge.svg?branch=main)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/test-coverage.yaml)
[![pkgdown-all](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/pkgdown-all.yaml/badge.svg?branch=main)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/pkgdown-all.yaml)

</div>

<div class="pkgdown-devel">

[![R-CMD-check](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/R-CMD-check.yaml/badge.svg?branch=dev)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/test-coverage.yaml/badge.svg?branch=dev)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/test-coverage.yaml)
[![pkgdown-all](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/pkgdown-all.yaml/badge.svg?branch=dev)](https://github.com/Gilead-BioStats/gsm.kri/actions/workflows/pkgdown-all.yaml)

</div>

<!-- badges: end -->

The {gsm} ecosystem provides a standardized Risk Based Quality Monitoring (RBQM) framework for clinical trials that pairs a flexible data pipeline with robust reports like the one shown below.  

<center> 
 
![](man/figures/gsm_report_screenshot_1.png)

</center>


The `{gsm.kri}` package provides the necessary functions and workflows to produce the data visualizations, widgets and tables that ultimately go into an html KRI report. This package also provides the functions and scripts that generate the html KRI reports.
This README provides a high-level overview of {gsm.kri}; see the [package website](https://gilead-biostats.github.io/gsm.kri/) for additional details.

## Installation

You can install the latest release of gsm.kri from [GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("Gilead-BioStats/gsm.kri@*release")
```

<div class="pkgdown-devel">

You can install the development version of gsm.kri from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("Gilead-BioStats/gsm.kri")
```

</div>

## Sample Code

This is a basic example showing how to create interactive widget visualizations based on reporting outputs from the `{gsm.reporting}` package:

``` r
library(gsm.kri)
library(gsm.core)

#### Visualize SAE Metric distribution using Bar Charts using provided htmlwidgets
labels <- list(  
  Metric= "Serious Adverse Event Rate",
  Numerator= "Serious Adverse Events",
  Denominator= "Days on Study"
)

# filter gsm sample data for one KRI and one snapshot
SAE_KRI <- reportingResults %>% 
            dplyr::filter(MetricID == "Analysis_kri0002" & SnapshotDate == "2012-12-31")

Widget_BarChart(dfResults = SAE_KRI, lMetric=labels, strOutcome="Metric")
Widget_BarChart(dfResults = SAE_KRI, lMetric=labels, strOutcome="Score")
Widget_BarChart(dfResults = SAE_KRI, lMetric=labels, strOutcome="Numerator")

### Create SAE Scatter plot with confidence bounds
dfBounds <- gsm.core::reportingBounds %>%
              dplyr::filter(MetricID == "Analysis_kri0002" & SnapshotDate == "2012-12-31")
Widget_ScatterPlot(SAE_KRI, lMetric = labels, dfBounds = dfBounds)

#### Site-Level KRI Report with multiple SnapshotDate

# First, create a list of charts using data output from `{gsm.reporting}` 
# For this example, we are using sample reporting data from `{gsm}`
lCharts <- MakeCharts(
  dfResults = gsm.core::reportingResults,
  dfGroups = gsm.core::reportingGroups,
  dfMetrics = gsm.core::reportingMetrics,
  dfBounds = gsm.core::reportingBounds
)

# Feed charts and reporting data into `Report_KRI()` to create the html report.
kri_report_path <- Report_KRI(
  lCharts = lCharts,
  dfResults =  FilterByLatestSnapshotDate(gsm.core::reportingResults),
  dfGroups =  gsm.core::reportingGroups,
  dfMetrics = gsm.core::reportingMetrics
)
```
Full reports for a sample trial run with [`{clindata}`](https://github.com/Gilead-BioStats/clindata) are provided below:

- [Site Report](https://gilead-biostats.github.io/gsm.kri/report_kri_site.html)
- [Country Report](https://gilead-biostats.github.io/gsm.kri/report_kri_country.html)

## Chart Customization

All widgets can be customized with any configuration setting available via the underlying
[JavaScript library API](https://github.com/Gilead-BioStats/gsm.viz/wiki/API) at the report, chart, or metric
level. Customize a widget by passing any configuration setting as an argument to the widget
function. Below we can change the default x-axis type of `logarithmic` to `linear` for the scatter
plot widget:

``` r
## Filter data to one metric and snapshot
reportingResults_filter <- gsm.core::reportingResults %>%
  dplyr::filter(MetricID == "Analysis_kri0001" & SnapshotDate == max(SnapshotDate))

reportingMetrics_filter <- gsm.core::reportingMetrics %>%
  dplyr::filter(MetricID == "Analysis_kri0001") %>%
  as.list()

reportingBounds_filter <- gsm.core::reportingBounds %>%
  dplyr::filter(MetricID == "Analysis_kri0001" & SnapshotDate == max(SnapshotDate))

Widget_ScatterPlot(
  dfResults = reportingResults_filter,
  lMetric = reportingMetrics_filter,
  dfGroups = gsm.core::reportingGroups,
  dfBounds = reportingBounds_filter,
  xType = "linear"  # Change x-axis type to linear
)
```

In the context of a workflow, you can also customize the chart configuration by passing a list of
settings to the `Report_KRI()` function:

``` r
lWorkflow <-     yaml::read_yaml(text = '
steps:
  - output: lCharts
    name: gsm.kri::MakeCharts
    params:
      dfResults: Reporting_Results
      dfGroups: Reporting_Groups
      dfBounds: Reporting_Bounds
      dfMetrics: Reporting_Metrics
      # applies to all charts
      resultTooltipKeys:
        - Numerator
        - Denominator
        - Metric
        - Score
      # applies to all scatter plots
      Widget_ScatterPlot:
        yType: logarithmic
      # applies to scatter plot only for kri0013
      Analysis_kri0013:
        Widget_ScatterPlot:
          xType: linear
')

lCharts <- RunWorkflow(
    lWorkflow = lWorkflow,
    lData = list(
        Reporting_Results = gsm.core::reportingResults,
        Reporting_Metrics = gsm.core::reportingMetrics,
        Reporting_Groups = gsm.core::reportingGroups,
        Reporting_Bounds = gsm.core::reportingBounds
    )
)
```
