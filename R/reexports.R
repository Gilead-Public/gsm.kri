# The legacy widget wrappers moved to gsm.vizr (#291). These re-exports keep the
# gsm.kri::* names working for existing callers (report Rmds, study code, gsm.app).

#' @export
#' @importFrom gsm.vizr Widget_BarChart
gsm.vizr::Widget_BarChart

#' @export
#' @importFrom gsm.vizr Widget_BarChartOutput
gsm.vizr::Widget_BarChartOutput

#' @export
#' @importFrom gsm.vizr renderWidget_BarChart
gsm.vizr::renderWidget_BarChart

#' @export
#' @importFrom gsm.vizr Widget_ScatterPlot
gsm.vizr::Widget_ScatterPlot

#' @export
#' @importFrom gsm.vizr Widget_ScatterPlotOutput
gsm.vizr::Widget_ScatterPlotOutput

#' @export
#' @importFrom gsm.vizr renderWidget_ScatterPlot
gsm.vizr::renderWidget_ScatterPlot

#' @export
#' @importFrom gsm.vizr Widget_TimeSeries
gsm.vizr::Widget_TimeSeries

#' @export
#' @importFrom gsm.vizr Widget_TimeSeriesOutput
gsm.vizr::Widget_TimeSeriesOutput

#' @export
#' @importFrom gsm.vizr renderWidget_TimeSeries
gsm.vizr::renderWidget_TimeSeries

#' @export
#' @importFrom gsm.vizr Widget_GroupOverview
gsm.vizr::Widget_GroupOverview

#' @export
#' @importFrom gsm.vizr Widget_GroupOverviewOutput
gsm.vizr::Widget_GroupOverviewOutput

#' @export
#' @importFrom gsm.vizr renderWidget_GroupOverview
gsm.vizr::renderWidget_GroupOverview

#' @export
#' @importFrom gsm.vizr MakeChartConfig
gsm.vizr::MakeChartConfig
