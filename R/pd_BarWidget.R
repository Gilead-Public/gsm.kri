#' Serialize a premature-death bar widget (internal)
#'
#' @description
#' Shared body for the two premature-death bar widgets
#' ([Widget_PrematureDeathBucketBar()] and [Widget_PrematureDeathReasonBar()]):
#' identical input validation plus JSON serialization, differing only by the
#' htmlwidget `strName` (which must match the registered JS/YAML pair). Holding
#' the contract in one place keeps the serialization args and the validation
#' messages from drifting between the two widgets.
#'
#' @param strName `character` Registered htmlwidget name.
#' @param data,spec,metadata,bDebug As documented on the calling widget.
#'
#' @return The `htmlwidget` from [htmlwidgets::createWidget()].
#' @noRd
pd_BarWidget <- function(strName, data, spec, metadata, bDebug) {
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

  lWidget <- htmlwidgets::createWidget(
    name = strName,
    purrr::map(
      list(data = data, spec = spec, metadata = metadata, bDebug = bDebug),
      ~ jsonlite::toJSON(.x, null = "null", na = "string", auto_unbox = TRUE)
    ),
    package = "gsm.kri",
    # gsmViz bundle comes from gsm.vizr now - the YAML can only resolve
    # package-relative paths inside gsm.kri, so the handoff is explicit here.
    dependencies = list(gsm.vizr::html_dependency_gsm_viz())
  )

  if (bDebug) {
    viewer <- getOption("viewer")
    options(viewer = NULL)
    print(lWidget)
    options(viewer = viewer)
  }
  lWidget
}
