# Eligibility report charts, on the IP Monitoring / gsm.stratification pattern:
# Study / Country / Site sections with Status, Flag Sources and Criteria tabs.
# R precomputes every slice (study, each country, each country's sites) into
# the #elig-data JSON block; inst/report/lib/eligFilters.js only picks the
# slice for the selected country or site. Colour encodes status, or Inclusion
# vs Exclusion, and nothing else.

ELIG_CRITERION_COLORS <- c(Inclusion = "#3C587F", Exclusion = "#8FB3DE", "Not classified" = "#B8C4D6")

elig_GroupCol <- function(strLevel) {
  switch(strLevel,
    study = "studyid",
    country = "country",
    site = "invid"
  )
}

#' Eligibility status bar rows
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per group and status with a non-zero count. Sites are in natural
#' alphanumeric order; study and country groups lead with the highest
#' Ineligible share, then any-risk share, then size.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param strLevel `character` One of `"study"`, `"country"` or `"site"`.
#'
#' @return `tibble` with `GroupID`, `OuterGroupID`, `Status`, `n` and `Level`.
#'
#' @keywords internal
#' @export
elig_StatusRows <- function(dfElig, strLevel = c("study", "country", "site")) {
  strLevel <- match.arg(strLevel)
  df <- tibble::tibble(
    GroupID = as.character(dfElig[[elig_GroupCol(strLevel)]]),
    OuterGroupID = if (strLevel == "site") as.character(dfElig$country) else NA_character_,
    Status = as.character(dfElig$status)
  )
  ord <- if (strLevel == "site") {
    stringr::str_sort(unique(df$GroupID), numeric = TRUE)
  } else {
    df %>%
      dplyr::summarise(
        inel = mean(.data$Status == ELIG_INELIGIBLE),
        risk = mean(.data$Status != ELIG_NO_RISK),
        n = dplyr::n(),
        .by = "GroupID"
      ) %>%
      dplyr::arrange(dplyr::desc(.data$inel), dplyr::desc(.data$risk), dplyr::desc(.data$n), .data$GroupID) %>%
      dplyr::pull("GroupID")
  }
  df %>%
    dplyr::count(.data$GroupID, .data$OuterGroupID, .data$Status, name = "n") %>%
    dplyr::mutate(n = as.integer(.data$n), Level = strLevel) %>%
    dplyr::arrange(match(.data$GroupID, ord), match(.data$Status, names(elig_StatusColors())))
}

elig_PctCountLabel <- function() {
  gsm.vizr::js_hook(
    "function (value, context, details) {
      var pct = Number(details.percent).toFixed(1) + '%';
      return details.valueType === 'percent'
        ? pct + ' (' + details.value + ')'
        : details.value + ' (' + pct + ')';
    }"
  )
}

elig_PctCountTooltip <- function() {
  gsm.vizr::js_hook(
    "function (count, context, details) {
      var spec = context.chart.data._spec_ || {};
      var pct = Number(details.percent).toFixed(1) + '%';
      var percentFirst = spec.stat === 'percent' || spec.position === 'fill';
      return context.dataset.label + ': ' +
        (percentFirst ? pct + ' (' + count + ')' : count + ' (' + pct + ')');
    }"
  )
}

#' Eligibility status bar chart specification
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' 100% stacked for the study, stacked counts for countries and sites.
#'
#' @param strLevel `character` One of `"study"`, `"country"` or `"site"`.
#' @param vOrder `character` Group order, or `NULL`.
#' @param bPilot `logical` Three statuses (pilot mode) or two.
#'
#' @return `list` chart specification for `gsm.vizr::bars()`.
#'
#' @keywords internal
#' @export
elig_StatusBarSpec <- function(strLevel = c("study", "country", "site"), vOrder = NULL, bPilot = FALSE) {
  strLevel <- match.arg(strLevel)
  segment <- list(display = TRUE, value = "auto", formatter = elig_PctCountLabel())
  if (strLevel == "study") {
    segment$avoidCategoryOverlap <- FALSE
    segment$minSize <- 80
  }
  spec <- list(
    mapping = list(x = "GroupID", y = "n", fill = "Status"),
    orientation = if (strLevel == "study") "horizontal" else "vertical",
    position = if (strLevel == "study") "fill" else "stack",
    scales = list(
      x = c(
        list(label = switch(strLevel, study = "", country = "Country", site = "Site")),
        if (!is.null(vOrder)) list(order = as.list(unique(vOrder)))
      ),
      y = list(label = "Enrolled participants"),
      fill = list(colors = as.list(elig_StatusColors(bPilot)), label = "")
    ),
    labels = list(title = "Enrolled participants by eligibility status"),
    annotations = list(labels = list(segment = segment)),
    tooltip = list(formatter = elig_PctCountTooltip()),
    # Drops a group a legend click leaves at 0, and brings it back with the series.
    theme = list(dynamicCategoryAxis = TRUE)
  )
  if (strLevel != "study") {
    spec$zoom <- list(enabled = TRUE, mode = "x")
    spec$labels$captions <- "Scroll to zoom in; drag to pan."
  }
  spec
}

#' Status over time chart specification
#'
#' @return `list` chart specification for `gsm.vizr::bars()`.
#'
#' @keywords internal
#' @export
elig_TrendBarSpec <- function() {
  spec <- elig_StatusBarSpec("country", bPilot = TRUE)
  spec$zoom <- NULL
  spec$position <- "fill"
  spec$scales$x$label <- "Snapshot"
  spec$labels <- list(title = "Enrolled participants by eligibility status over time")
  spec
}

#' Show filter above the country or site status chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Buttons keep only the groups with at least one participant in the given
#' statuses; their bars keep every status. Each button carries its statuses
#' as JSON, so the report's JavaScript holds no status names.
#'
#' @param strLevel `character` One of `"country"` or `"site"`.
#' @param bPilot `logical` Offer "With any risk" (pilot mode).
#'
#' @return `htmltools` tag.
#'
#' @keywords internal
#' @export
elig_StatusFilter <- function(strLevel = c("country", "site"), bPilot = FALSE) {
  strLevel <- match.arg(strLevel)
  vNoun <- switch(strLevel, country = c("country", "countries"), site = c("site", "sites"))
  lOptions <- c(
    list(list(label = "All", statuses = character())),
    if (isTRUE(bPilot)) list(list(label = "With any risk", statuses = c(ELIG_INELIGIBLE, ELIG_POTENTIAL))),
    list(list(label = "With Ineligible", statuses = ELIG_INELIGIBLE))
  )
  buttons <- lapply(seq_along(lOptions), function(i) {
    htmltools::tags$button(
      type = "button",
      class = if (i == 1) "active",
      `aria-pressed` = if (i == 1) "true" else "false",
      `data-elig-statuses` = as.character(jsonlite::toJSON(lOptions[[i]]$statuses)),
      lOptions[[i]]$label
    )
  })
  htmltools::tags$div(
    id = paste0("elig-", strLevel, "-status-filter"),
    class = "elig-status-filter",
    `data-elig-status-filter` = strLevel,
    `data-elig-noun` = vNoun[[1]],
    `data-elig-nouns` = vNoun[[2]],
    htmltools::tags$span(class = "elig-status-filter-label", paste0("Show ", vNoun[[2]], ":")),
    htmltools::tags$div(
      class = "elig-status-filter-options", role = "group",
      `aria-label` = paste("Show", vNoun[[2]], "by eligibility status"),
      buttons
    ),
    htmltools::tags$span(class = "elig-status-count", `aria-live` = "polite"),
    htmltools::tags$div(
      class = "elig-status-empty", style = "display:none;",
      paste0("No ", vNoun[[2]], " in scope have the selected status.")
    )
  )
}

#' Breakdown slices
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per key and fill value with at least one row of `dfRecords` in
#' scope, for the study, each country and each country's sites, so a chart
#' draws no empty category. The caller
#' passes one row per participant, key and fill value. `pct` is over enrolled
#' participants in scope.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param dfRecords `data.frame` with `subjid`, `key` and `status`.
#' @param vOrder `character` Key order.
#' @param vStatuses `character` Fill values, in stack order.
#'
#' @return `list` with `order`, `study`, `country` and `site` (by country, then
#'   site). `pct` is rounded to 1 decimal.
#'
#' @keywords internal
#' @export
elig_BreakdownRows <- function(dfElig, dfRecords, vOrder, vStatuses) {
  dfRecords <- dfRecords[c("subjid", "key", "status")] %>%
    dplyr::left_join(dfElig[c("subjid", "country", "invid")], by = "subjid")
  grid <- tidyr::expand_grid(key = vOrder, Status = vStatuses)
  slice <- function(bSubj, bRec) {
    nEnrolled <- sum(bSubj)
    counts <- dplyr::count(dfRecords[bRec, ], .data$key, Status = .data$status, name = "n")
    grid %>%
      dplyr::left_join(counts, by = c("key", "Status")) %>%
      dplyr::mutate(
        n = dplyr::coalesce(as.integer(.data$n), 0L),
        pct = if (nEnrolled > 0) round(100 * .data$n / nEnrolled, 1) else 0
      ) %>%
      dplyr::filter(.data$n > 0)
  }
  vCountries <- sort(unique(dfElig$country), method = "radix")
  lSites <- lapply(vCountries, function(c) {
    vSites <- sort(unique(dfElig$invid[dfElig$country == c]), method = "radix")
    stats::setNames(lapply(vSites, function(s) {
      slice(dfElig$country == c & dfElig$invid == s, dfRecords$country %in% c & dfRecords$invid %in% s)
    }), vSites)
  })
  list(
    order = vOrder,
    study = slice(rep(TRUE, nrow(dfElig)), rep(TRUE, nrow(dfRecords))),
    country = stats::setNames(
      lapply(vCountries, function(c) slice(dfElig$country == c, dfRecords$country %in% c)),
      vCountries
    ),
    site = stats::setNames(lSites, vCountries)
  )
}

#' Flag source slices
#'
#' One bar per delivered source that flagged a participant in scope, counting
#' the participants it flagged, stacked
#' by their overall status (Ineligible wins). A participant counts under every
#' source that flagged them.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `list` from [elig_BreakdownRows()].
#'
#' @keywords internal
#' @export
elig_SourceRows <- function(dfElig) {
  vSources <- elig_Sources(dfElig)
  vSources <- vSources[vapply(names(vSources), function(f) elig_HasSource(dfElig, f), logical(1))]
  long <- purrr::map_dfr(names(vSources), function(f) {
    hit <- dfElig[dfElig[[f]] %in% "Y", ]
    tibble::tibble(subjid = hit$subjid, key = unname(vSources[[f]]), status = hit$status)
  })
  if (nrow(long) == 0) long <- tibble::tibble(subjid = character(), key = character(), status = character())
  # Pilot frames always carry flag_edc_query, NA when the source is not delivered.
  vStatuses <- names(elig_StatusColors("flag_edc_query" %in% names(dfElig)))
  elig_BreakdownRows(dfElig, long, unname(vSources), setdiff(vStatuses, ELIG_NO_RISK))
}

#' Criterion slices (criteria view A)
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `list` from [elig_BreakdownRows()], keyed by criterion code and
#'   filled by Inclusion / Exclusion / Not classified. Each scope holds only the criteria with
#'   cases in it.
#'
#' @keywords internal
#' @export
elig_CriteriaRows <- function(dfElig) {
  long <- elig_CriteriaLong(dfElig)
  vOrder <- elig_CriteriaOrder(long)
  vTypes <- intersect(names(ELIG_CRITERION_COLORS), unique(long$type))
  elig_BreakdownRows(
    dfElig,
    dplyr::transmute(long, .data$subjid, key = .data$criterion, status = .data$type),
    vOrder,
    if (length(vTypes)) vTypes else c("Inclusion", "Exclusion")
  )
}

elig_CriteriaOrder <- function(dfCrit) {
  if (nrow(dfCrit) == 0) return(character())
  dfCrit %>%
    dplyr::count(.data$criterion, .data$type) %>%
    dplyr::arrange(match(.data$type, names(ELIG_CRITERION_COLORS)), dplyr::desc(.data$n)) %>%
    dplyr::pull("criterion") %>%
    unique()
}

#' Breakdown bar chart specification
#'
#' Horizontal stacked participant counts with the total past the bar end.
#'
#' @param vOrder `character` Key order.
#' @param strAxisLabel `character` Category axis label.
#' @param vColors `character` Colours named by fill value, in stack order.
#'
#' @return `list` chart specification for `gsm.vizr::bars()`.
#'
#' @keywords internal
#' @export
elig_BreakdownBarSpec <- function(vOrder, strAxisLabel, vColors) {
  list(
    mapping = list(x = "key", y = "n", fill = "Status"),
    orientation = "horizontal",
    position = "stack",
    stat = "identity",
    theme = list(dynamicCategoryAxis = TRUE),
    scales = list(
      x = list(label = strAxisLabel, order = as.list(vOrder)),
      y = list(label = "Participants flagged"),
      fill = list(colors = as.list(vColors), label = "")
    ),
    annotations = list(
      labels = list(
        segment = list(
          display = length(vColors) > 1,
          formatter = gsm.vizr::js_hook(
            "function (value, context, details) {
              var d = (details && details.datum) || {};
              return d.n > 0 ? String(d.n) : '';
            }"
          )
        ),
        total = list(display = TRUE)
      )
    ),
    tooltip = list(
      formatter = gsm.vizr::js_hook(
        "function (count, context, details) {
          var d = (details && details.datum) || {};
          return context.dataset.label + ': ' + d.n + ' participants (' +
            Number(d.pct).toFixed(1) + '% of enrolled)';
        }"
      )
    )
  )
}

#' Criteria map rows (criteria view B)
#'
#' Participants per group and criterion, for the country and site maps. Only
#' groups with at least one criterion case appear; the report hides criteria
#' with no case among the rows shown.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `list` with `order` (criteria), `country` and `site` rows
#'   (`GroupID`, `OuterGroupID`, `criterion`, `n`).
#'
#' @keywords internal
#' @export
elig_CriteriaMapRows <- function(dfElig) {
  long <- elig_CriteriaLong(dfElig)
  vOrder <- elig_CriteriaOrder(long)
  rows <- function(group, outer) {
    long %>%
      dplyr::count(GroupID = .data[[group]], OuterGroupID = if (is.null(outer)) NA_character_ else .data[[outer]], .data$criterion) %>%
      dplyr::mutate(n = as.integer(.data$n)) %>%
      dplyr::arrange(.data$GroupID)
  }
  list(
    order = vOrder,
    country = rows("country", NULL),
    site = rows("invid", "country")
  )
}

#' Precomputed eligibility slices as a JSON script block
#'
#' Read by `inst/report/lib/eligFilters.js`.
#'
#' @param lData `list` Slices to embed.
#'
#' @return `htmltools` script tag.
#'
#' @keywords internal
#' @export
elig_DataScript <- function(lData) {
  json <- jsonlite::toJSON(lData, dataframe = "rows", na = "null", null = "null", digits = NA)
  htmltools::tags$script(
    type = "application/json",
    id = "elig-data",
    htmltools::HTML(gsub("<", "\\\\u003c", json))
  )
}
