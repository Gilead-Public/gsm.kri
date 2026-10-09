#' Discontinuation reason slices for the IP Compliance reasons charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Splits each premature treatment discontinuation's comma-separated reasons
#' and counts the participant once under each reason. Every slice lists every
#' reason in `order`, zeros included, because gsm.viz drops an ordered
#' category that has no row. `pct` is over the dosed participants in scope,
#' which is the same for the All and Dosed filters.
#'
#' @param dfIPC `data.frame` Output of [ipc_ClassifyParticipants()].
#' @param bHasPTD `logical` Whether premature treatment discontinuation data
#'   was delivered.
#'
#' @return `NULL` when `bHasPTD` is `FALSE`; otherwise a `list` with `order`
#'   (reasons by study-wide frequency, ties alphabetical), `study`,
#'   `country[[country]]`, `site[[country]][[invid]]` and `zero` (the Not dosed
#'   filter). Each slice is a `tibble` with `reason`, `n` and `pct`.
#' @keywords internal
#' @export
ipc_ReasonRows <- function(dfIPC, bHasPTD) {
  if (!bHasPTD) {
    return(NULL)
  }
  dfDosed <- dfIPC[
    dfIPC$dosed %in% "Y",
    c("country", "invid", "status", "ptd_reason")
  ]
  dfPTD <- dfDosed[dfDosed$status %in% "Premature treatment discontinuation", ]
  lReasons <- lapply(dfPTD$ptd_reason, function(x) {
    reasons <- unique(trimws(strsplit(
      dplyr::coalesce(x, ""),
      ",",
      fixed = TRUE
    )[[1]]))
    reasons <- reasons[nzchar(reasons)]
    if (length(reasons) == 0) "Not yet recorded" else reasons
  })
  nReasons <- lengths(lReasons)
  dfLong <- tibble::tibble(
    country = rep(dfPTD$country, nReasons),
    invid = rep(dfPTD$invid, nReasons),
    reason = as.character(unlist(lReasons))
  )
  counts <- dplyr::count(dfLong, .data$reason)
  vOrder <- counts$reason[order(-counts$n, counts$reason, method = "radix")]

  slice <- function(bLong, bDosed) {
    n <- vapply(vOrder, function(r) sum(dfLong$reason[bLong] == r), integer(1))
    nDosed <- sum(bDosed)
    tibble::tibble(
      reason = vOrder,
      n = unname(n),
      pct = if (nDosed > 0) 100 * unname(n) / nDosed else 0
    )
  }
  vCountries <- sort(unique(dfIPC$country), method = "radix")
  lSites <- lapply(vCountries, function(c) {
    vSites <- sort(unique(dfIPC$invid[dfIPC$country == c]), method = "radix")
    stats::setNames(
      lapply(vSites, function(s) {
        slice(
          dfLong$country == c & dfLong$invid == s,
          dfDosed$country == c & dfDosed$invid == s
        )
      }),
      vSites
    )
  })
  list(
    order = vOrder,
    study = slice(rep(TRUE, nrow(dfLong)), rep(TRUE, nrow(dfDosed))),
    country = stats::setNames(
      lapply(vCountries, function(c) {
        slice(dfLong$country == c, dfDosed$country == c)
      }),
      vCountries
    ),
    # Keyed by country, then site, so two countries' "Unknown" sites stay apart.
    site = stats::setNames(lSites, vCountries),
    zero = tibble::tibble(reason = vOrder, n = rep(0L, length(vOrder)), pct = 0)
  )
}

#' gsm.viz spec for the IP Compliance reasons charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Horizontal bars of % of dosed participants per reason, most frequent at the
#' top. Labels and hover read "x.x% (n)".
#'
#' @param vReasonOrder `character` Reasons in display order, from
#'   [ipc_ReasonRows()].
#'
#' @return A named `list` for [gsm.vizr::bars()].
#' @keywords internal
#' @export
ipc_ReasonBarSpec <- function(vReasonOrder) {
  label <- gsm.vizr::js_hook(
    "function (value, context, details) {
      var d = (details && details.datum) || {};
      return Number(d.pct).toFixed(1) + '% (' + d.n + ')';
    }"
  )
  strColor <- ipc_StatusColors()[["Premature treatment discontinuation"]]
  list(
    mapping = list(x = "reason", y = "pct"),
    orientation = "horizontal",
    position = "stack",
    stat = "identity",
    scales = list(
      x = list(label = "", order = as.list(vReasonOrder)),
      y = list(label = "% of dosed participants"),
      fill = list(palette = list(strColor))
    ),
    # Labels sit past the bar end. gsm.viz would otherwise measure label width
    # against bar height and drop every label on these horizontal bars.
    annotations = list(
      labels = list(
        segment = list(
          display = TRUE,
          formatter = label,
          placement = "end",
          avoidCategoryOverlap = FALSE
        )
      )
    ),
    tooltip = list(formatter = label)
  )
}
