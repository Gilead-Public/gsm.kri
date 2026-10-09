#' Inline data block for the IP Compliance filter script
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Serializes every precomputed chart slice into a JSON script tag that the
#' report's filter script reads. Each `<` is escaped so no value can close the
#' block.
#'
#' @param lData `list` Status rows and reason slices.
#'
#' @return An `htmltools` `<script type="application/json" id="ipc-data">` tag.
#' @keywords internal
#' @export
ipc_DataScript <- function(lData) {
  json <- jsonlite::toJSON(
    lData,
    dataframe = "rows",
    na = "null",
    null = "null",
    digits = NA
  )
  htmltools::tags$script(
    type = "application/json",
    id = "ipc-data",
    htmltools::HTML(gsub("<", "\\\\u003c", json))
  )
}
