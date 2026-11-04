#' Long status rows for the IP Monitoring status charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Participant counts per group and status, once for every dosed filter
#' (`"all"`, `"Y"`, `"N"`), so the report's filter script only picks rows.
#' Participants whose dosed flag is unrecognised appear under `"all"` only.
#'
#' @param dfIPM `data.frame` Output of [ipm_ClassifyParticipants()].
#' @param strLevel `character` `"study"`, `"country"` or `"site"`.
#'
#' @return A `tibble` with `Dosed`, `GroupID`, `OuterGroupID` (country for
#'   site rows, else `NA`), `Status`, `n` and `Level`. Only non-zero cells.
#' @keywords internal
#' @export
ipm_StatusRows <- function(dfIPM, strLevel = c("study", "country", "site")) {
  strLevel <- match.arg(strLevel)
  strGroupCol <- switch(
    strLevel,
    study = "studyid",
    country = "country",
    site = "invid"
  )
  df <- tibble::tibble(
    # Character, not factor: a factor would pin an x order that updateData
    # then carries into every narrowed slice.
    GroupID = as.character(dfIPM[[strGroupCol]]),
    OuterGroupID = if (strLevel == "site") dfIPM$country else NA_character_,
    Status = as.character(dfIPM$status),
    dosed = dfIPM$dosed
  )
  dplyr::bind_rows(
    dplyr::mutate(df, Dosed = "all"),
    dplyr::mutate(
      dplyr::filter(df, .data$dosed %in% c("Y", "N")),
      Dosed = .data$dosed
    )
  ) %>%
    dplyr::count(
      .data$Dosed,
      .data$GroupID,
      .data$OuterGroupID,
      .data$Status,
      name = "n"
    ) %>%
    dplyr::mutate(n = as.integer(.data$n), Level = strLevel) %>%
    dplyr::arrange(
      match(.data$Dosed, c("all", "Y", "N")),
      .data$GroupID,
      match(.data$Status, names(ipm_StatusColors()))
    )
}

#' gsm.viz spec for the IP Monitoring status charts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A 100% stacked bar per group. Labels and hover lead with the value the axis
#' shows: "62.3% (41)" in fill mode, "41 (62.3%)" in count mode. The study
#' chart is one horizontal bar; the country and site charts zoom and pan.
#'
#' @param strLevel `character` `"study"`, `"country"` or `"site"`.
#'
#' @return A named `list` for [gsm.vizr::bars()].
#' @keywords internal
#' @export
ipm_StatusBarSpec <- function(strLevel = c("study", "country", "site")) {
  strLevel <- match.arg(strLevel)
  segment <- list(
    display = TRUE,
    value = "auto",
    formatter = gsm.vizr::js_hook(
      "function (value, context, details) {
        var pct = Number(details.percent).toFixed(1) + '%';
        return details.valueType === 'percent'
          ? pct + ' (' + details.value + ')'
          : details.value + ' (' + pct + ')';
      }"
    )
  )
  if (strLevel == "study") {
    # The single horizontal bar is thinner than a two-number label, so labels
    # are fitted by segment length instead.
    segment$avoidCategoryOverlap <- FALSE
    segment$minSize <- 80
  }
  spec <- list(
    mapping = list(x = "GroupID", y = "n", fill = "Status"),
    orientation = if (strLevel == "study") "horizontal" else "vertical",
    # No stat: gsm.viz turns fill into percent only when stat is unset.
    position = "fill",
    scales = list(
      x = list(
        label = switch(strLevel, study = "", country = "Country", site = "Site")
      ),
      # Mode-neutral: the position toggle cannot change the axis title.
      y = list(label = "Participants"),
      fill = list(colors = as.list(ipm_StatusColors()), label = "")
    ),
    # A title row gives the position toggle its own line above the legend.
    labels = list(title = "Participants by status"),
    annotations = list(labels = list(segment = segment)),
    tooltip = list(
      formatter = gsm.vizr::js_hook(
        "function (count, context, details) {
          var spec = context.chart.data._spec_ || {};
          var pct = Number(details.percent).toFixed(1) + '%';
          var percentFirst = spec.stat === 'percent' || spec.position === 'fill';
          return context.dataset.label + ': ' +
            (percentFirst ? pct + ' (' + count + ')' : count + ' (' + pct + ')');
        }"
      )
    )
  )
  if (strLevel != "study") {
    spec$zoom <- list(enabled = TRUE, mode = "x")
    spec$labels$captions <- "Scroll to zoom in; drag to pan."
  }
  if (strLevel == "site") {
    spec$theme <- list(dynamicCategoryAxis = TRUE)
  }
  spec
}
