#' Premature-death reason bar widget (gsm.viz)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' htmlwidget wrapper rendering the horizontal reason-distribution bar via
#' `gsm.viz` `bars`. Serializes long rows from [pd_ReasonRows()] plus the
#' serializable spec from [pd_ReasonBarSpec()]; the widget JS attaches the
#' tooltip formatter. When `metadata` carries a `reactive` map of per-country
#' row frames, the widget swaps its data via `helpers.updateData` on the
#' `pdBucketFilterChanged` event so a country click reshapes the reason bar
#' without a second spec definition.
#'
#' @param data `data.frame` Rows from [pd_ReasonRows()] (the initial `__ALL__`
#'   slice).
#' @param spec `list` Serializable spec from [pd_ReasonBarSpec()].
#' @param metadata `list` Report keys (`chartId`, `level`, ...); may include
#'   `reactive`, a named list of per-country row `data.frame`s keyed by country
#'   plus `__ALL__`.
#' @param bDebug `logical` Log the serialized input to the browser console.
#'   Default `FALSE`.
#'
#' @return A `Widget_PrematureDeathReasonBar` htmlwidget.
#' @export
Widget_PrematureDeathReasonBar <- function(
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
    name = "Widget_PrematureDeathReasonBar",
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

#' Shiny bindings for Widget_PrematureDeathReasonBar
#' @param outputId,width,height,expr,env,quoted htmlwidgets Shiny binding params.
#' @name Widget_PrematureDeathReasonBar-shiny
#' @export
Widget_PrematureDeathReasonBarOutput <- function(
  outputId,
  width = "100%",
  height = "400px"
) {
  htmlwidgets::shinyWidgetOutput(
    outputId,
    "Widget_PrematureDeathReasonBar",
    width,
    height,
    package = "gsm.kri"
  )
}
#' @rdname Widget_PrematureDeathReasonBar-shiny
#' @export
renderWidget_PrematureDeathReasonBar <- function(
  expr,
  env = parent.frame(),
  quoted = FALSE
) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(
    expr,
    Widget_PrematureDeathReasonBarOutput,
    env,
    quoted = TRUE
  )
}
