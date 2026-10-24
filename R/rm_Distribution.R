#' Participant distribution rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Evaluable participants per group, KRI vital and flag. Study rows have one
#' bar per vital; country and site rows have one chart per vital.
#'
#' @param dfParticipants `data.frame` `participants` from [rm_Classify()].
#' @param strLevel `character` `"study"`, `"country"` or `"site"`.
#'
#' @return A `tibble` with `vital`, `GroupID` (the vital's short label for
#'   study rows), `OuterGroupID` (country for site rows, else `NA`), `Flag`,
#'   `n` and `Level`, sorted so each chart's groups run from the highest to
#'   the lowest \% flagged. Only non-zero cells.
#' @keywords internal
#' @export
rm_DistributionRows <- function(dfParticipants, strLevel = c("study", "country", "site")) {
  strLevel <- match.arg(strLevel)
  dfVitals <- rm_Vitals()
  df <- dfParticipants[dfParticipants$flag %in% c("Red", "Amber", "Green"), ]
  df <- tibble::tibble(
    vital = df$vital,
    GroupID = switch(
      strLevel,
      study = dfVitals$short[match(df$vital, dfVitals$vital)],
      country = as.character(df$country),
      site = as.character(df$invid)
    ),
    OuterGroupID = if (strLevel == "site") as.character(df$country) else NA_character_,
    Flag = as.character(df$flag)
  )
  dfOrder <- df %>%
    dplyr::group_by(.data$vital, .data$GroupID) %>%
    dplyr::summarise(
      pct = mean(.data$Flag != "Green"),
      evaluable = dplyr::n(),
      .groups = "drop"
    )
  df %>%
    dplyr::count(.data$vital, .data$GroupID, .data$OuterGroupID, .data$Flag, name = "n") %>%
    dplyr::left_join(dfOrder, by = c("vital", "GroupID")) %>%
    dplyr::arrange(
      match(.data$vital, dfVitals$vital),
      -.data$pct,
      -.data$evaluable,
      .data$GroupID,
      match(.data$Flag, names(rm_FlagColors()))
    ) %>%
    dplyr::transmute(
      .data$vital,
      .data$GroupID,
      .data$OuterGroupID,
      .data$Flag,
      n = as.integer(.data$n),
      Level = strLevel
    )
}

#' gsm.viz spec for the Repeat Measurements distribution charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The IP Monitoring status bar ([ipm_StatusBarSpec()]) recoloured by flag:
#' a 100\% stacked bar of evaluable participants per group, in the order
#' given. Country and site charts zoom and pan; the zoom is the requirement's
#' site slider.
#'
#' @param strLevel `character` `"study"`, `"country"` or `"site"`.
#' @param vOrder `character` Group order, highest percent flagged first.
#' @param strTitle `character` Chart title.
#'
#' @return A named `list` for [gsm.vizr::bars()].
#' @keywords internal
#' @export
rm_DistributionSpec <- function(
  strLevel = c("study", "country", "site"),
  vOrder = NULL,
  strTitle = "Evaluable participants by flag"
) {
  strLevel <- match.arg(strLevel)
  spec <- ipm_StatusBarSpec(strLevel)
  spec$mapping$fill <- "Flag"
  spec$scales$x$label <- switch(strLevel, study = "", country = "Country", site = "Site")
  spec$scales$x$order <- as.list(vOrder)
  spec$scales$y$label <- "Evaluable participants"
  spec$scales$fill$colors <- as.list(rm_FlagColors()[c("Red", "Amber", "Green")])
  spec$labels$title <- strTitle
  if (strLevel != "study") {
    spec$labels$captions <- "Sorted by % flagged. Scroll to zoom in; drag to pan; click a bar to filter."
  }
  spec
}

#' Site KRI flags for the Repeat Measurements distribution charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The latest site-level `kri0020a`–`f` flag per site, keyed by vital.
#'
#' @param dfResults `data.frame` Reporting results.
#'
#' @return A named `list` (vital to a named list of site flags); empty when
#'   `dfResults` has no `kri0020` site results.
#' @keywords internal
#' @export
rm_SiteFlags <- function(dfResults) {
  vNeeded <- c("MetricID", "GroupLevel", "GroupID", "Flag")
  if (is.null(dfResults) || !all(vNeeded %in% names(dfResults))) {
    return(stats::setNames(list(), character(0)))
  }
  df <- dfResults[grepl("^Analysis_kri0020[a-f]$", dfResults$MetricID) &
    dfResults$GroupLevel %in% "Site" & !is.na(dfResults$Flag), ]
  if ("SnapshotDate" %in% names(df) && nrow(df) > 0) {
    df <- df[as.Date(df$SnapshotDate) == max(as.Date(df$SnapshotDate)), ]
  }
  dfVitals <- rm_Vitals()
  df$vital <- dfVitals$vital[match(sub("^Analysis_", "", df$MetricID), dfVitals$metric)]
  lapply(split(df, df$vital), function(d) {
    as.list(stats::setNames(as.integer(d$Flag), as.character(d$GroupID)))
  })
}
