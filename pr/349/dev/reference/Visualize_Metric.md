# Visualize_Metric Function

\`r lifecycle::badge("stable")\`

The function creates all available charts for a metric using the data
provided

## Usage

``` r
Visualize_Metric(
  dfResults = dfResults,
  dfMetrics = NULL,
  dfGroups = NULL,
  dfBounds = NULL,
  strMetricID = NULL,
  strSnapshotDate = NULL,
  bDebug = FALSE,
  ...
)
```

## Arguments

- dfResults:

  \`data.frame\` A stacked summary of analysis pipeline output. Created
  by passing a list of results returned by \[Summarize()\] to
  \[BindResults()\]. Expected columns: \`GroupID\`, \`GroupLevel\`,
  \`Numerator\`, \`Denominator\`, \`Metric\`, \`Score\`, \`Flag\`,
  \`MetricID\`, \`StudyID\`, \`SnapshotDate\`.

- dfMetrics:

  \`data.frame\` Metric-specific metadata for use in charts and
  reporting. Created by passing an \`lWorkflow\` object to
  \[MakeMetric()\]. Expected columns: \`File\`, \`MetricID\`, \`Group\`,
  \`Abbreviation\`, \`Metric\`, \`Numerator\`, \`Denominator\`,
  \`Model\`, \`Score\`, and \`Threshold\`. For more details see the Data
  Model vignette: \`vignette("DataModel", package = "gsm.core")\`.

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- dfBounds:

  \`data.frame\` Set of predicted percentages/rates and upper- and
  lower-bounds across the full range of sample sizes/total exposure
  values for reporting. Created by passing \`dfResults\` and
  \`dfMetrics\` to \[MakeBounds()\]. Expected columns: \`Threshold\`,
  \`Denominator\`, \`Numerator\`, \`Metric\`, \`MetricID\`, \`StudyID\`,
  \`SnapshotDate\`.

- strMetricID:

  \`character\` MetricID to subset the data.

- strSnapshotDate:

  \`character\` Snapshot date to subset the data.

- bDebug:

  \`logical\` Display console in html viewer for debugging. Default is
  \`FALSE\`.

- ...:

  Additional chart configuration settings.

## Value

A list containing the following charts: - scatterPlot: A scatter plot
using JavaScript. - barChart: A bar chart using JavaScript with metric
on the y-axis. - timeSeries: A time series chart using JavaScript with
score on the y-axis. - metricTable: A table containing all

## Examples

``` r
lCharts <- Visualize_Metric(
  dfResults = gsm.core::reportingResults,
  dfBounds = gsm.core::reportingBounds,
  dfGroups = gsm.core::reportingGroups,
  dfMetrics = gsm.core::reportingMetrics,
  strMetricID = "Analysis_kri0001"
)
#> Parsed -2,-1,2,3 to numeric vector: -2, -1, 2, 3
#> Error in (function (data, table.width = NULL, table.layout = NULL, table.align = NULL,     table.margin.left = NULL, table.margin.right = NULL, table.background.color = NULL,     table.no_data_message = NULL, table.additional_css = NULL,     table.font.names = NULL, table.font.size = NULL, table.font.weight = NULL,     table.font.style = NULL, table.font.color = NULL, table.font.color.light = NULL,     table.border.top.style = NULL, table.border.top.width = NULL,     table.border.top.color = NULL, table.border.right.style = NULL,     table.border.right.width = NULL, table.border.right.color = NULL,     table.border.bottom.style = NULL, table.border.bottom.width = NULL,     table.border.bottom.color = NULL, table.border.left.style = NULL,     table.border.left.width = NULL, table.border.left.color = NULL,     heading.background.color = NULL, heading.align = NULL, heading.title.font.size = NULL,     heading.title.font.weight = NULL, heading.subtitle.font.size = NULL,     heading.subtitle.font.weight = NULL, heading.padding = NULL,     heading.padding.horizontal = NULL, heading.border.bottom.style = NULL,     heading.border.bottom.width = NULL, heading.border.bottom.color = NULL,     heading.border.lr.style = NULL, heading.border.lr.width = NULL,     heading.border.lr.color = NULL, column_labels.background.color = NULL,     column_labels.font.size = NULL, column_labels.font.weight = NULL,     column_labels.text_transform = NULL, column_labels.padding = NULL,     column_labels.padding.horizontal = NULL, column_labels.vlines.style = NULL,     column_labels.vlines.width = NULL, column_labels.vlines.color = NULL,     column_labels.border.top.style = NULL, column_labels.border.top.width = NULL,     column_labels.border.top.color = NULL, column_labels.border.bottom.style = NULL,     column_labels.border.bottom.width = NULL, column_labels.border.bottom.color = NULL,     column_labels.border.lr.style = NULL, column_labels.border.lr.width = NULL,     column_labels.border.lr.color = NULL, column_labels.hidden = NULL,     column_labels.units_pattern = NULL, row_group.background.color = NULL,     row_group.font.size = NULL, row_group.font.weight = NULL,     row_group.text_transform = NULL, row_group.padding = NULL,     row_group.padding.horizontal = NULL, row_group.border.top.style = NULL,     row_group.border.top.width = NULL, row_group.border.top.color = NULL,     row_group.border.bottom.style = NULL, row_group.border.bottom.width = NULL,     row_group.border.bottom.color = NULL, row_group.border.left.style = NULL,     row_group.border.left.width = NULL, row_group.border.left.color = NULL,     row_group.border.right.style = NULL, row_group.border.right.width = NULL,     row_group.border.right.color = NULL, row_group.default_label = NULL,     row_group.as_column = NULL, table_body.hlines.style = NULL,     table_body.hlines.width = NULL, table_body.hlines.color = NULL,     table_body.vlines.style = NULL, table_body.vlines.width = NULL,     table_body.vlines.color = NULL, table_body.border.top.style = NULL,     table_body.border.top.width = NULL, table_body.border.top.color = NULL,     table_body.border.bottom.style = NULL, table_body.border.bottom.width = NULL,     table_body.border.bottom.color = NULL, stub.background.color = NULL,     stub.font.size = NULL, stub.font.weight = NULL, stub.text_transform = NULL,     stub.border.style = NULL, stub.border.width = NULL, stub.border.color = NULL,     stub.indent_length = NULL, stub.separate = NULL, stub_row_group.font.size = NULL,     stub_row_group.font.weight = NULL, stub_row_group.text_transform = NULL,     stub_row_group.border.style = NULL, stub_row_group.border.width = NULL,     stub_row_group.border.color = NULL, data_row.padding = NULL,     data_row.padding.horizontal = NULL, summary_row.background.color = NULL,     summary_row.text_transform = NULL, summary_row.padding = NULL,     summary_row.padding.horizontal = NULL, summary_row.border.style = NULL,     summary_row.border.width = NULL, summary_row.border.color = NULL,     grand_summary_row.background.color = NULL, grand_summary_row.text_transform = NULL,     grand_summary_row.padding = NULL, grand_summary_row.padding.horizontal = NULL,     grand_summary_row.border.style = NULL, grand_summary_row.border.width = NULL,     grand_summary_row.border.color = NULL, footnotes.background.color = NULL,     footnotes.font.size = NULL, footnotes.padding = NULL, footnotes.padding.horizontal = NULL,     footnotes.border.bottom.style = NULL, footnotes.border.bottom.width = NULL,     footnotes.border.bottom.color = NULL, footnotes.border.lr.style = NULL,     footnotes.border.lr.width = NULL, footnotes.border.lr.color = NULL,     footnotes.marks = NULL, footnotes.spec_ref = NULL, footnotes.spec_ftr = NULL,     footnotes.multiline = NULL, footnotes.sep = NULL, footnotes.order = NULL,     source_notes.background.color = NULL, source_notes.font.size = NULL,     source_notes.padding = NULL, source_notes.padding.horizontal = NULL,     source_notes.border.bottom.style = NULL, source_notes.border.bottom.width = NULL,     source_notes.border.bottom.color = NULL, source_notes.border.lr.style = NULL,     source_notes.border.lr.width = NULL, source_notes.border.lr.color = NULL,     source_notes.multiline = NULL, source_notes.sep = NULL, row.striping.background_color = NULL,     row.striping.include_stub = NULL, row.striping.include_table_body = NULL,     container.width = NULL, container.height = NULL, container.padding.x = NULL,     container.padding.y = NULL, container.overflow.x = NULL,     container.overflow.y = NULL, ihtml.active = NULL, ihtml.use_pagination = NULL,     ihtml.use_pagination_info = NULL, ihtml.use_sorting = NULL,     ihtml.use_search = NULL, ihtml.use_filters = NULL, ihtml.use_resizers = NULL,     ihtml.use_highlight = NULL, ihtml.use_compact_mode = NULL,     ihtml.use_text_wrapping = NULL, ihtml.use_page_size_select = NULL,     ihtml.page_size_default = NULL, ihtml.page_size_values = NULL,     ihtml.pagination_type = NULL, ihtml.height = NULL, ihtml.selection_mode = NULL,     page.orientation = NULL, page.numbering = NULL, page.header.use_tbl_headings = NULL,     page.footer.use_tbl_notes = NULL, page.width = NULL, page.height = NULL,     page.margin.left = NULL, page.margin.right = NULL, page.margin.top = NULL,     page.margin.bottom = NULL, page.header.height = NULL, page.footer.height = NULL,     quarto.use_bootstrap = NULL, quarto.disable_processing = NULL,     latex.use_longtable = NULL, latex.header_repeat = NULL, latex.toprule = NULL,     latex.bottomrule = NULL, latex.tbl.pos = NULL, latex.unicode_conversion = NULL) {    stop_if_not_gt_tbl(data = data)    opts_df <- dt_options_get(data = data)    arg_names <- base::setdiff(names(formals(tab_options)), c("data",         "ihtml.page_size_values", "ihtml.page_size_default"))    arg_vals <- mget(arg_names)    arg_vals <- arg_vals[!vapply(arg_vals, FUN = is.null, FUN.VALUE = logical(1))]    arg_vals <- set_super_options(arg_vals = arg_vals)    new_df <- vctrs::data_frame(parameter = gsub(".", "_", names(arg_vals),         fixed = TRUE), value = unname(arg_vals))    new_df <- dplyr::left_join(new_df, dplyr::select(opts_df,         "parameter", "type"), by = "parameter")    new_df$value <- mapply(preprocess_tab_option, option = new_df$value,         var_name = new_df$parameter, type = new_df$type, SIMPLIFY = FALSE)    new_df$type <- NULL    opts_df <- dplyr::bind_rows(dplyr::inner_join(new_df, dplyr::select(opts_df,         -"value"), by = "parameter"), dplyr::anti_join(opts_df,         new_df, by = "parameter"))    data <- dt_options_set(data = data, options = opts_df)    ihtml_page_size_values <- mget("ihtml.page_size_values")    if (!is.null(ihtml_page_size_values[[1]])) {        data <- dt_options_set_value(data = data, option = "ihtml_page_size_values",             value = unname(unlist(ihtml_page_size_values)))    }    ihtml_page_size_default <- mget("ihtml.page_size_default")    if (!is.null(ihtml_page_size_default[[1]])) {        data <- dt_options_set_value(data = data, option = "ihtml_page_size_default",             value = unname(unlist(ihtml_page_size_default)))    }    data})(data = structure(list(StudyID = c("AA-AA-000-0000", "AA-AA-000-0000", "AA-AA-000-0000", "AA-AA-000-0000", "AA-AA-000-0000", "AA-AA-000-0000", "AA-AA-000-0000"), GroupID = c("0X9490", "0X6995", "0X4747", "0X700", "0X2861", "0X8090", "0X9252"), MetricID = c("Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0001", "Analysis_kri0001"), Group = structure(c("0X9490 (Doe)", "0X6995 (Deer)", "0X4747 (Doe)", "0X700 (Deer)", "0X2861 (Deer)", "0X8090 (Doe)", "0X9252 (Smith)"), class = c("glue", "character")), SnapshotDate = structure(c(20179, 20179, 20179, 20179, 20179, 20179, 20179), class = "Date"), Enrolled = c(13L, 7L, 4L, 4L, 4L, 9L, 11L), Numerator = c(25L, 13L, 5L, 0L, 6L, 16L, 33L),     Denominator = c(532L, 306L, 151L, 50L, 165L, 318L, 554L),     Metric = c(0.05, 0.04, 0.03, 0, 0.04, 0.05, 0.06), Score = c(-1.56,     -1.34, -1.17, -1.14, -1.14, -1.09, -1), Flag = c(-1L, -1L,     -1L, -1L, -1L, -1L, -1L)), row.names = c(NA, -7L), class = "data.frame"),     heading.padding = "2px", column_labels.padding = "2.5px",     row_group.padding = "4px", data_row.padding = "4px", summary_row.padding = "4px",     grand_summary_row.padding = "4px", footnotes.padding = "2px",     source_notes.padding = "2px"): `data` must be a `gt_tbl` object, not a data frame.
```
