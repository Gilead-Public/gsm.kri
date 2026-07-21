#' Premature-death bucket bar widget (gsm.viz)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' htmlwidget wrapper that renders premature-death category counts via
#' `gsm.viz` `bars` (study) or `facetBars` (country/site). Serializes long rows
#' from [pd_BucketRows()] plus the serializable spec from [pd_BucketBarSpec()];
#' the widget JS attaches the tooltip formatter and click/hover callbacks.
#'
#' @param data `data.frame` Long rows from [pd_BucketRows()].
#' @param spec `list` Serializable `bars`/`facetBars` spec from [pd_BucketBarSpec()].
#' @param metadata `list` Report keys (`chartId`, `level`, ...) for linked filtering.
#' @param bDebug `logical` Log the serialized input to the browser console. Default `FALSE`.
#'
#' @return A `Widget_PrematureDeathBucketBar` htmlwidget.
#' @export
Widget_PrematureDeathBucketBar <- function(
  data,
  spec,
  metadata = list(),
  bDebug = FALSE
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(data),
    message = "data is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !(is.list(spec) && !is.data.frame(spec)),
    message = "spec must be a list"
  )
  gsm.core::stop_if(
    cnd = !(is.list(metadata) && !is.data.frame(metadata)),
    message = "metadata must be a list"
  )
  gsm.core::stop_if(
    cnd = !is.logical(bDebug),
    message = "bDebug must be logical"
  )

  lInput <- list(data = data, spec = spec, metadata = metadata, bDebug = bDebug)

  lWidget <- htmlwidgets::createWidget(
    name = "Widget_PrematureDeathBucketBar",
    purrr::map(
      lInput,
      ~ jsonlite::toJSON(.x, null = "null", na = "string", auto_unbox = TRUE)
    ),
    package = "gsm.kri"
  )

  if (bDebug) {
    viewer <- getOption("viewer")
    options(viewer = NULL)
    print(lWidget)
    options(viewer = viewer)
  }
  lWidget
}

#' Shiny bindings for Widget_PrematureDeathBucketBar
#' @param outputId,width,height,expr,env,quoted htmlwidgets Shiny binding params.
#' @name Widget_PrematureDeathBucketBar-shiny
#' @export
Widget_PrematureDeathBucketBarOutput <- function(
  outputId,
  width = "100%",
  height = "400px"
) {
  htmlwidgets::shinyWidgetOutput(
    outputId,
    "Widget_PrematureDeathBucketBar",
    width,
    height,
    package = "gsm.kri"
  )
}
#' @rdname Widget_PrematureDeathBucketBar-shiny
#' @export
renderWidget_PrematureDeathBucketBar <- function(
  expr,
  env = parent.frame(),
  quoted = FALSE
) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(
    expr,
    Widget_PrematureDeathBucketBarOutput,
    env,
    quoted = TRUE
  )
}
