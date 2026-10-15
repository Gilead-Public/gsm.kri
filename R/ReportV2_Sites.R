#' @describeIn ReportV2 Per-site risk data behind the Sites tab: site summaries
#'   ranked by risk score, one cell per site and KRI, and KRI-level study rates.
#'   Each cell carries flag bands converted to the rate scale, so the site panel
#'   can draw a bullet chart of the site rate against the study rate.
ReportV2_SiteData <- function(dfResults, dfMetrics, dfGroups, lCharts = NULL) {
  dfCurrent <- v2_current(dfResults)
  vInactive <- v2_inactive_ids(dfMetrics)
  bHasPrevious <- "Flag_Previous" %in% names(dfCurrent)
  dfBounds <- v2_chart_bounds(lCharts)

  dfKRI <- dfMetrics[v2_is_kri(dfMetrics$MetricID), ]
  dfKRI <- dfKRI[order(dfKRI$MetricID %in% vInactive), ]
  col_or_na <- function(df, strCol) if (strCol %in% names(df)) df[[strCol]] else rep(NA_character_, nrow(df))

  dfMetricInfo <- tibble::tibble(
    MetricID = dfKRI$MetricID,
    abbr = col_or_na(dfKRI, "Abbreviation"),
    name = col_or_na(dfKRI, "Metric"),
    num_label = col_or_na(dfKRI, "Numerator"),
    den_label = col_or_na(dfKRI, "Denominator"),
    threshold = col_or_na(dfKRI, "Threshold"),
    flags = col_or_na(dfKRI, "Flag"),
    inactive = dfKRI$MetricID %in% vInactive
  )
  dfMetricInfo$scale <- vapply(dfMetricInfo$MetricID, function(strMetric) {
    v2_score_scale(
      dfCurrent[dfCurrent$MetricID == strMetric, ],
      any(dfBounds$MetricID == strMetric)
    )
  }, character(1), USE.NAMES = FALSE)
  dfMetricInfo$study_rate <- vapply(dfMetricInfo$MetricID, function(strMetric) {
    dfM <- dfCurrent[dfCurrent$MetricID == strMetric & !is.na(dfCurrent$Numerator) & !is.na(dfCurrent$Denominator), ]
    if (nrow(dfM) == 0 || sum(dfM$Denominator) == 0) NA_real_ else sum(dfM$Numerator) / sum(dfM$Denominator)
  }, numeric(1), USE.NAMES = FALSE)
  # Fallback bands (10th, 25th, 75th, 90th percentile of site rates) where flag bands cannot be derived.
  dfMetricInfo$quantiles <- lapply(dfMetricInfo$MetricID, function(strMetric) {
    vRate <- dfCurrent$Metric[dfCurrent$MetricID == strMetric]
    vRate <- vRate[is.finite(vRate)]
    if (length(vRate) < 4) NULL else unname(stats::quantile(vRate, c(0.1, 0.25, 0.75, 0.9)))
  })

  dfWeights <- v2_weights(dfMetrics)
  dfCells <- dfCurrent[dfCurrent$MetricID %in% dfMetricInfo$MetricID, ]
  dfCells <- tibble::tibble(
    GroupID = dfCells$GroupID,
    MetricID = dfCells$MetricID,
    flag = as.numeric(dfCells$Flag),
    prev = if (bHasPrevious) as.numeric(dfCells$Flag_Previous) else NA_real_,
    score = dfCells$Score,
    num = dfCells$Numerator,
    den = dfCells$Denominator,
    rate = dfCells$Metric
  ) %>%
    dplyr::mutate(
      inactive = .data$MetricID %in% vInactive,
      change = if (bHasPrevious) v2_change(.data$flag, .data$prev) else NA_character_
    ) %>%
    dplyr::left_join(dfWeights, by = c("MetricID", "flag" = "Flag")) %>%
    dplyr::rename(weight = "Weight")
  dfCells$bands <- lapply(seq_len(nrow(dfCells)), function(i) {
    lInfo <- dfMetricInfo[dfMetricInfo$MetricID == dfCells$MetricID[i], ]
    v2_rate_bands(
      lInfo$threshold, lInfo$flags, dfCells$den[i], lInfo$scale,
      dfBounds[dfBounds$MetricID == dfCells$MetricID[i], ]
    )
  })

  dfActive <- dfCells[!dfCells$inactive, ]
  absActive <- abs(dfActive$flag)
  dfCounts <- tibble::tibble(GroupID = unique(dfCells$GroupID)) %>%
    dplyr::mutate(
      red = vapply(.data$GroupID, function(g) sum(absActive[dfActive$GroupID == g] == 2, na.rm = TRUE), numeric(1), USE.NAMES = FALSE),
      amber = vapply(.data$GroupID, function(g) sum(absActive[dfActive$GroupID == g] == 1, na.rm = TRUE), numeric(1), USE.NAMES = FALSE),
      new_flags = vapply(.data$GroupID, function(g) {
        bSite <- dfActive$GroupID == g
        sum(bSite & dfActive$change %in% c("new", "worse") & absActive >= 1, na.rm = TRUE)
      }, numeric(1), USE.NAMES = FALSE)
    )

  strGroupLevel <- v2_group_level(dfMetrics)
  vSRS <- v2_site_srs(dfResults)
  dfSites <- dfCounts %>%
    dplyr::mutate(
      label = v2_group_param(dfGroups, strGroupLevel, .data$GroupID, "InvestigatorLastName"),
      city = v2_group_param(dfGroups, strGroupLevel, .data$GroupID, "City"),
      country = v2_group_param(dfGroups, strGroupLevel, .data$GroupID, "Country"),
      enrolled = suppressWarnings(as.numeric(
        v2_group_param(dfGroups, strGroupLevel, .data$GroupID, "ParticipantCount")
      )),
      srs = unname(vSRS[.data$GroupID])
    ) %>%
    dplyr::arrange(
      dplyr::desc(dplyr::coalesce(.data$srs, -Inf)),
      dplyr::desc(.data$red),
      dplyr::desc(.data$amber),
      dplyr::desc(.data$new_flags),
      .data$GroupID
    ) %>%
    dplyr::mutate(rank = seq_len(dplyr::n())) %>%
    dplyr::select("GroupID", "label", "city", "country", "enrolled", "srs", "rank", "red", "amber", "new_flags")

  list(
    sites = dfSites,
    cells = dfCells,
    metrics = dfMetricInfo,
    group_level = strGroupLevel,
    has_changes = bHasPrevious
  )
}

#' @describeIn ReportV2 Sites tab: risk-ranked heatmap (left) and site details (right).
#' @param lSiteData `list` Output of `ReportV2_SiteData()`.
ReportV2_SitesTab <- function(lSiteData) {
  dfSites <- lSiteData$sites
  dfCells <- lSiteData$cells
  dfActive <- lSiteData$metrics[!lSiteData$metrics$inactive, ]
  strGroupLevel <- lSiteData$group_level
  strGroups <- tolower(paste0(strGroupLevel, "s"))
  vFlagName <- c(r = "Red", a = "Amber", g = "Green", n = "No flag")

  cell_td <- function(strSite, strMetric, strAbbr) {
    dfCell <- dfCells[dfCells$GroupID == strSite & dfCells$MetricID == strMetric, ]
    if (nrow(dfCell) == 0) {
      return(htmltools::tags$td(class = "v2-cell n", title = paste0(strAbbr, ": no data")))
    }
    strClass <- v2_flag_class(dfCell$flag)
    bWorse <- isTRUE(dfCell$change %in% c("new", "worse")) && strClass %in% c("r", "a")
    strTitle <- paste0(
      strAbbr, ": ", vFlagName[[strClass]],
      if (!is.na(dfCell$flag) && dfCell$flag != 0) if (dfCell$flag > 0) " (above)" else " (below)",
      if (isTRUE(dfCell$change == "new")) " \u00B7 new flag",
      if (isTRUE(dfCell$change == "worse")) paste0(" \u00B7 up from ", vFlagName[[v2_flag_class(dfCell$prev)]]),
      if (isTRUE(dfCell$change == "better")) paste0(" \u00B7 down from ", vFlagName[[v2_flag_class(dfCell$prev)]]),
      if (!is.na(dfCell$score)) sprintf(" \u00B7 score %.2f", dfCell$score)
    )
    htmltools::tags$td(
      class = paste(c("v2-cell", strClass, if (bWorse) "worse"), collapse = " "),
      title = strTitle,
      htmltools::tags$span(class = "v2-sr", strTitle)
    )
  }

  rows <- lapply(seq_len(nrow(dfSites)), function(i) {
    lSite <- dfSites[i, ]
    strPlace <- paste(stats::na.omit(c(lSite$label, lSite$country)), collapse = " \u00B7 ")
    htmltools::tags$tr(
      class = "v2-site-row",
      `data-site` = lSite$GroupID,
      `data-red` = lSite$red,
      `data-amber` = lSite$amber,
      `data-new` = lSite$new_flags,
      tabindex = "0",
      htmltools::tags$td(
        class = "v2-site-cell",
        htmltools::tags$div(
          class = "v2-site-id",
          htmltools::tags$b(class = "v2-mono", lSite$GroupID),
          if (lSite$new_flags > 0) {
            htmltools::tags$span(
              class = "v2-badge v2-new-badge",
              title = sprintf("%d new or escalated flag%s since the previous snapshot", lSite$new_flags, if (lSite$new_flags == 1) "" else "s"),
              paste(lSite$new_flags, "new")
            )
          }
        ),
        htmltools::tags$span(class = "v2-site-sub", strPlace)
      ),
      htmltools::tags$td(
        class = "v2-risk-cell",
        .noWS = "inside",
        if (is.na(lSite$srs)) {
          htmltools::tags$span(class = "v2-muted", "\u2013")
        } else {
          htmltools::tags$span(class = "v2-num", sprintf("%.1f", lSite$srs))
        }
      ),
      lapply(seq_len(nrow(dfActive)), function(j) cell_td(lSite$GroupID, dfActive$MetricID[j], dfActive$abbr[j]))
    )
  })

  # Estimated content width of the site column (ID + badge, or the sub-line).
  vPlace <- vapply(seq_len(nrow(dfSites)), function(i) {
    paste(stats::na.omit(c(dfSites$label[i], dfSites$country[i])), collapse = " \u00B7 ")
  }, character(1))
  vIdWidth <- nchar(dfSites$GroupID) * 8 + ifelse(dfSites$new_flags > 0, 50, 0)
  intSiteWidth <- as.integer(ceiling(max(c(96, vIdWidth, nchar(vPlace) * 6.4)) + 24))

  intRed <- sum(dfSites$red > 0)
  intFlagged <- sum(dfSites$red + dfSites$amber > 0)
  intNew <- sum(dfSites$new_flags > 0)
  filter_button <- function(strValue, strLabel, intCount, bSelected = FALSE) {
    htmltools::tags$button(
      type = "button",
      role = "tab",
      `data-filter` = strValue,
      `aria-selected` = tolower(bSelected),
      strLabel, " ", htmltools::tags$span(class = "v2-badge neutral", intCount)
    )
  }

  htmltools::tags$div(
    class = "v2-split v2-sites",
    htmltools::tags$section(
      class = "v2-card v2-pane-left",
      `aria-label` = paste(strGroupLevel, "overview"),
      htmltools::tags$div(
        class = "v2-toolbar",
        htmltools::tags$div(
          class = "v2-seg v2-site-filter",
          role = "tablist",
          `aria-label` = paste("Filter", strGroups),
          filter_button("all", paste("All", strGroups), nrow(dfSites), TRUE),
          filter_button("red", "1+ red", intRed),
          filter_button("flagged", "1+ flag", intFlagged),
          if (lSiteData$has_changes) filter_button("new", "New flags", intNew)
        ),
        htmltools::tags$div(
          class = "v2-legend",
          htmltools::tags$span(htmltools::tags$i(class = "v2-key r"), "Red"),
          htmltools::tags$span(htmltools::tags$i(class = "v2-key a"), "Amber"),
          htmltools::tags$span(htmltools::tags$i(class = "v2-key g"), "Green"),
          htmltools::tags$span(htmltools::tags$i(class = "v2-key n"), "No data"),
          if (lSiteData$has_changes) htmltools::tags$span(htmltools::tags$i(class = "v2-key a worse"), "New or worse")
        )
      ),
      htmltools::tags$div(
        class = "v2-table-scroll",
        htmltools::tags$table(
          id = "v2-site-table",
          class = "v2-heatmap",
          # Fixed layout: the site column is sized to its content (refined in the
          # browser) and the KRI columns split the remaining width equally.
          style = sprintf(
            "min-width:%dpx;--v2-site-w:%dpx",
            intSiteWidth + 48 + 32 * nrow(dfActive) + 2 * (nrow(dfActive) + 3),
            intSiteWidth
          ),
          htmltools::tags$colgroup(
            htmltools::tags$col(class = "v2-site-col"),
            htmltools::tags$col(class = "v2-risk-col"),
            lapply(seq_len(nrow(dfActive)), function(j) htmltools::tags$col(class = "v2-kri-col"))
          ),
          htmltools::tags$thead(htmltools::tags$tr(
            htmltools::tags$th(class = "v2-site-cell", scope = "col", strGroupLevel),
            htmltools::tags$th(class = "v2-risk-cell", scope = "col", title = "Site risk score", "Risk"),
            lapply(seq_len(nrow(dfActive)), function(j) {
              htmltools::tags$th(scope = "col", title = dfActive$name[j], dfActive$abbr[j])
            })
          )),
          htmltools::tags$tbody(rows)
        )
      ),
      htmltools::tags$div(class = "v2-empty v2-filter-empty", hidden = NA, paste("No", strGroups, "match this filter."))
    ),
    htmltools::tags$aside(
      class = "v2-card v2-pane-right v2-site-panel",
      id = "v2-site-panel",
      `aria-live` = "polite",
      htmltools::tags$div(
        class = "v2-panel-empty",
        htmltools::tags$div(class = "v2-panel-empty-icon", `aria-hidden` = "true", "\u2190"),
        htmltools::tags$h3(paste("Select a", tolower(strGroupLevel))),
        htmltools::tags$p(
          paste0(
            "Choose a row to see the ", tolower(strGroupLevel),
            "'s flagged KRIs, ranked by their contribution to the risk score, with its rate against the study rate. ",
            "Use \u2191 \u2193 to move between rows."
          )
        )
      )
    ),
    htmltools::tags$script(
      type = "application/json",
      id = "v2-site-data",
      htmltools::HTML(v2_site_json(lSiteData))
    )
  )
}

#' @describeIn ReportV2 Main tab bar (Overview, Sites, Metrics).
#' @param lCounts `list` Optional badges per tab, named `overview`, `sites`, `metrics`.
ReportV2_TabBar <- function(strGroupLevel = "Site", lCounts = list()) {
  vTabs <- c(overview = "Overview", sites = paste0(strGroupLevel, "s"), metrics = "Metrics")
  htmltools::tags$div(
    class = "v2-tabbar",
    id = "v2-tabbar",
    htmltools::tags$div(
      class = "v2-tabbar-inner",
      role = "tablist",
      `aria-label` = "Report views",
      lapply(seq_along(vTabs), function(i) {
        strTab <- names(vTabs)[i]
        htmltools::tags$button(
          type = "button",
          role = "tab",
          class = "v2-maintab",
          id = paste0("v2-tab-", strTab),
          `data-tab` = strTab,
          `aria-controls` = paste0("v2-panel-", strTab),
          `aria-selected` = tolower(i == 1),
          vTabs[[i]],
          if (!is.null(lCounts[[strTab]])) htmltools::tags$span(class = "v2-badge neutral", lCounts[[strTab]])
        )
      })
    )
  )
}

# Helpers -------------------------------------------------------------------

v2_site_srs <- function(dfResults) {
  dfSRS <- dfResults[!v2_is_kri(dfResults$MetricID) & !is.na(dfResults$Score), ]
  if ("SnapshotDate" %in% names(dfSRS) && nrow(dfSRS) > 0) {
    dfSRS <- dfSRS[dfSRS$SnapshotDate == max(dfSRS$SnapshotDate), ]
  }
  stats::setNames(dfSRS$Score, dfSRS$GroupID)
}

v2_group_param <- function(dfGroups, strGroupLevel, vGroupID, strParam) {
  if (is.null(dfGroups) || !"Param" %in% names(dfGroups)) {
    return(rep(NA_character_, length(vGroupID)))
  }
  dfParam <- dfGroups[dfGroups$GroupLevel == strGroupLevel & dfGroups$Param == strParam, ]
  unname(stats::setNames(as.character(dfParam$Value), dfParam$GroupID)[vGroupID])
}

v2_change <- function(flag, prev) {
  absNow <- abs(flag)
  absPrev <- abs(prev)
  dplyr::case_when(
    is.na(flag) & is.na(prev) ~ "same",
    is.na(prev) & absNow >= 1 ~ "new",
    is.na(prev) ~ "same",
    is.na(flag) ~ "nodata",
    absNow > absPrev ~ "worse",
    absNow < absPrev ~ "better",
    flag != prev ~ "flip",
    TRUE ~ "same"
  )
}

v2_weights <- function(dfMetrics) {
  dfEmpty <- tibble::tibble(MetricID = character(), Flag = numeric(), Weight = numeric())
  if (!all(c("Flag", "RiskScoreWeight") %in% names(dfMetrics))) {
    return(dfEmpty)
  }
  dfW <- tryCatch(
    suppressWarnings(MakeWeights(dfMetrics)),
    error = function(e) NULL
  )
  if (is.null(dfW) || nrow(dfW) == 0) {
    return(dfEmpty)
  }
  tibble::tibble(MetricID = dfW$MetricID, Flag = as.numeric(dfW$Flag), Weight = as.numeric(dfW$Weight))
}

# How a metric's Score relates to its rate, which decides how thresholds map onto rates:
# "bounds" (normal approximation, via the scatter plot bounds), "numerator" (identity on
# counts), "rate" (identity on the rate itself), or NA when unknown.
v2_score_scale <- function(dfMetricResults, bHasBounds = FALSE) {
  if (bHasBounds) {
    return("bounds")
  }
  dfM <- dfMetricResults[!is.na(dfMetricResults$Score), ]
  if (nrow(dfM) == 0) {
    return(NA_character_)
  }
  if (all(abs(dfM$Score - dfM$Numerator) < 1e-9, na.rm = TRUE)) {
    return("numerator")
  }
  if (all(abs(dfM$Score - dfM$Metric) < 1e-9, na.rm = TRUE)) {
    return("rate")
  }
  NA_character_
}

# Score intervals and their flags, using gsm.core::Flag() so the mapping matches the workflows.
v2_score_bands <- function(strThreshold, strFlag) {
  if (length(strThreshold) != 1 || length(strFlag) != 1 || is.na(strThreshold) || is.na(strFlag)) {
    return(NULL)
  }
  vThreshold <- sort(suppressWarnings(as.numeric(strsplit(strThreshold, ",")[[1]])))
  vFlag <- suppressWarnings(as.numeric(strsplit(strFlag, ",")[[1]]))
  if (anyNA(vThreshold) || anyNA(vFlag) || length(vThreshold) == 0) {
    return(NULL)
  }
  vProbe <- c(
    vThreshold[1] - 1,
    (utils::head(vThreshold, -1) + utils::tail(vThreshold, -1)) / 2,
    utils::tail(vThreshold, 1) + 1
  )
  dfFlagged <- tryCatch(
    suppressMessages(gsm.core::Flag(
      data.frame(GroupID = seq_along(vProbe), Score = vProbe),
      vThreshold = vThreshold,
      vFlag = vFlag
    )),
    error = function(e) NULL
  )
  if (is.null(dfFlagged)) {
    return(NULL)
  }
  dfFlagged <- dfFlagged[order(dfFlagged$GroupID), ]
  data.frame(
    lo = c(-Inf, vThreshold),
    hi = c(vThreshold, Inf),
    flag = as.numeric(dfFlagged$Flag)
  )
}

# Flag bands on the rate scale for one site, given its denominator.
v2_rate_bands <- function(strThreshold, strFlag, numDenominator, strScale, dfBounds = NULL) {
  dfBands <- v2_score_bands(strThreshold, strFlag)
  if (is.null(dfBands) || length(strScale) != 1 || is.na(strScale) ||
    is.na(numDenominator) || numDenominator <= 0) {
    return(NULL)
  }
  if (strScale == "bounds" && (is.null(dfBounds) || nrow(dfBounds) == 0)) {
    return(NULL)
  }

  to_rate <- function(numThreshold) {
    switch(strScale,
      rate = numThreshold,
      numerator = numThreshold / numDenominator,
      bounds = {
        dfT <- dfBounds[abs(dfBounds$Threshold - numThreshold) < 1e-9 &
          !is.na(dfBounds$Denominator) & !is.na(dfBounds$Metric), ]
        if (nrow(dfT) < 2) {
          NA_real_
        } else {
          stats::approx(dfT$Denominator, dfT$Metric, xout = numDenominator, rule = 2, ties = mean)$y
        }
      },
      NA_real_
    )
  }

  vEdge <- vapply(utils::head(dfBands$hi, -1), to_rate, numeric(1))
  # An edge without bounds collapses the band on its side of the green band.
  intGreen <- which(dfBands$flag == 0)[1]
  if (is.na(intGreen)) intGreen <- length(vEdge) + 1
  vMissing <- which(is.na(vEdge))
  vEdge[vMissing] <- ifelse(vMissing < intGreen, 0, Inf)
  vEdge <- cummax(pmax(vEdge, 0))

  dfRate <- data.frame(lo = c(0, vEdge), hi = c(vEdge, Inf), flag = dfBands$flag)
  dfRate <- dfRate[dfRate$hi > dfRate$lo, ]
  rownames(dfRate) <- NULL
  dfRate
}

# Latest-snapshot bounds embedded in the scatter plots of lCharts.
v2_chart_bounds <- function(lCharts) {
  dfEmpty <- tibble::tibble(MetricID = character(), Threshold = numeric(), Denominator = numeric(), Metric = numeric())
  if (!is.list(lCharts) || length(lCharts) == 0) {
    return(dfEmpty)
  }
  lBounds <- lapply(names(lCharts), function(strMetric) {
    for (chart in lCharts[[strMetric]]) {
      bounds <- tryCatch(chart$x$dfBounds, error = function(e) NULL)
      if (is.null(bounds)) next
      dfB <- if (is.data.frame(bounds)) bounds else tryCatch(jsonlite::fromJSON(as.character(bounds)), error = function(e) NULL)
      if (!is.data.frame(dfB) || !all(c("Threshold", "Denominator", "Metric") %in% names(dfB))) next
      if (!"MetricID" %in% names(dfB)) dfB$MetricID <- strMetric
      if ("SnapshotDate" %in% names(dfB) && nrow(dfB) > 0) {
        dfB <- dfB[as.character(dfB$SnapshotDate) == max(as.character(dfB$SnapshotDate)), ]
      }
      return(tibble::tibble(
        MetricID = as.character(dfB$MetricID),
        Threshold = as.numeric(dfB$Threshold),
        Denominator = as.numeric(dfB$Denominator),
        Metric = as.numeric(dfB$Metric)
      ))
    }
    NULL
  })
  dplyr::bind_rows(dfEmpty, lBounds)
}

# Compact JSON payload for the site panel; Inf band edges are written as null.
v2_site_json <- function(lSiteData) {
  signif_or_na <- function(x) ifelse(is.finite(x), signif(x, 4), NA_real_)
  dfCells <- lSiteData$cells
  lCells <- split(seq_len(nrow(dfCells)), dfCells$GroupID)
  lSites <- lapply(seq_len(nrow(lSiteData$sites)), function(i) {
    lSite <- as.list(lSiteData$sites[i, ])
    vIdx <- lCells[[lSite$GroupID]] %||% integer()
    list(
      id = lSite$GroupID, label = lSite$label, city = lSite$city, country = lSite$country,
      enrolled = lSite$enrolled, srs = signif_or_na(lSite$srs), rank = lSite$rank,
      red = lSite$red, amber = lSite$amber, new = lSite$new_flags,
      cells = lapply(vIdx, function(j) {
        dfB <- dfCells$bands[[j]]
        list(
          m = dfCells$MetricID[j], f = dfCells$flag[j], p = dfCells$prev[j], c = dfCells$change[j],
          s = signif_or_na(dfCells$score[j]), n = dfCells$num[j], d = dfCells$den[j],
          r = signif_or_na(dfCells$rate[j]), w = dfCells$weight[j],
          b = if (is.null(dfB)) NULL else lapply(seq_len(nrow(dfB)), function(k) {
            c(signif_or_na(dfB$lo[k]), signif_or_na(dfB$hi[k]), dfB$flag[k])
          })
        )
      })
    )
  })
  dfM <- lSiteData$metrics
  lMetrics <- lapply(seq_len(nrow(dfM)), function(i) {
    list(
      id = dfM$MetricID[i], abbr = dfM$abbr[i], name = dfM$name[i],
      num = dfM$num_label[i], den = dfM$den_label[i], scale = dfM$scale[i],
      studyRate = signif_or_na(dfM$study_rate[i]), inactive = dfM$inactive[i],
      q = if (is.null(dfM$quantiles[[i]])) NULL else signif(dfM$quantiles[[i]], 4)
    )
  })
  as.character(jsonlite::toJSON(
    list(
      groupLevel = lSiteData$group_level,
      hasChanges = lSiteData$has_changes,
      metrics = lMetrics,
      sites = lSites
    ),
    auto_unbox = TRUE, na = "null", null = "null", digits = NA
  ))
}
