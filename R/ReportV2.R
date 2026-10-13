#' Opt-in modern KRI report (v2) building blocks
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Internal helpers used by `inst/report/Report_KRI_v2.Rmd`, an opt-in template
#' rendered with
#' `Report_KRI(strInputPath = system.file("report", "Report_KRI_v2.Rmd", package = "gsm.kri"))`.
#' Each helper returns [htmltools::tags] so the whole page can be knit as a
#' single tag tree, which keeps htmlwidget dependencies de-duplicated.
#'
#' @inheritParams shared-params
#' @param lSetup `list` Output of [Report_Setup()].
#' @param lSummary `list` Output of `ReportV2_Summary()`.
#' @param lCharts `list` Charts for a single metric, as produced by [MakeCharts()].
#' @param lMetric `list` Metadata for a single metric (one row of `dfMetrics`).
#' @param strGroupLevel `character` Group level used in labels, e.g. `"Site"`.
#'
#' @name ReportV2
#' @keywords internal
NULL

v2_is_kri <- function(strMetricID) {
  !grepl("srs", strMetricID, ignore.case = TRUE)
}

v2_current <- function(dfResults) {
  if ("SnapshotDate" %in% names(dfResults) && nrow(dfResults) > 0) {
    dfResults <- dfResults[dfResults$SnapshotDate == max(dfResults$SnapshotDate), ]
  }
  dfResults[v2_is_kri(dfResults$MetricID), ]
}

v2_flag_class <- function(flag) {
  dplyr::case_when(
    is.na(flag) ~ "n",
    abs(flag) == 2 ~ "r",
    abs(flag) == 1 ~ "a",
    TRUE ~ "g"
  )
}

v2_flag_tag <- function(flag) {
  cls <- v2_flag_class(flag)
  label <- c(r = "Red", a = "Amber", g = "Green", n = "No flag")[[cls]]
  arrow <- if (is.na(flag) || flag == 0) "" else if (flag > 0) "\u25B2 " else "\u25BC "
  htmltools::tags$span(class = paste("v2-flagtag", cls), paste0(arrow, label))
}

v2_group_labels <- function(dfGroups, strGroupLevel = "Site") {
  if (is.null(dfGroups) || !"Param" %in% names(dfGroups)) {
    return(character())
  }
  dfLabels <- dfGroups %>%
    dplyr::filter(
      .data$GroupLevel == strGroupLevel,
      .data$Param == "InvestigatorLastName"
    )
  stats::setNames(dfLabels$Value, dfLabels$GroupID)
}

v2_group_label <- function(strGroupID, vLabels) {
  vLabel <- unname(vLabels[strGroupID])
  ifelse(is.na(vLabel), strGroupID, paste0(strGroupID, " (", vLabel, ")"))
}

v2_group_level <- function(dfMetrics) {
  strGroupLevel <- unique(dfMetrics$GroupLevel)
  if (length(strGroupLevel) == 1 && !is.na(strGroupLevel)) strGroupLevel else "Group"
}

v2_num <- function(x) {
  suppressWarnings(as.numeric(x %||% NA))
}

v2_signed <- function(x, digits = 2) {
  if (is.null(x) || is.na(x)) {
    return("\u2013")
  }
  sprintf(paste0("%+.", digits, "f"), as.numeric(x))
}

v2_badges <- function(intRed, intAmber) {
  htmltools::tagList(
    if (intRed > 0) htmltools::tags$span(class = "v2-badge red", intRed),
    if (intAmber > 0) htmltools::tags$span(class = "v2-badge amber", intAmber),
    if (intRed == 0 && intAmber == 0) {
      htmltools::tags$span(class = "v2-badge green", "\u2713")
    }
  )
}

v2_metric_counts <- function(dfResults, dfMetrics) {
  dfCurrent <- v2_current(dfResults)
  dfMetrics[v2_is_kri(dfMetrics$MetricID), ] %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      red = sum(abs(dfCurrent$Flag[dfCurrent$MetricID == .data$MetricID]) == 2, na.rm = TRUE),
      amber = sum(abs(dfCurrent$Flag[dfCurrent$MetricID == .data$MetricID]) == 1, na.rm = TRUE),
      n = sum(dfCurrent$MetricID == .data$MetricID)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(dplyr::desc(.data$red), dplyr::desc(.data$amber))
}

#' @describeIn ReportV2 Headline counts for the current snapshot.
ReportV2_Summary <- function(dfResults) {
  dfCurrent <- v2_current(dfResults)
  absFlag <- abs(dfCurrent$Flag)
  bHasPrevious <- "Flag_Previous" %in% names(dfCurrent)

  lSummary <- list(
    red = sum(absFlag == 2, na.rm = TRUE),
    amber = sum(absFlag == 1, na.rm = TRUE),
    red_previous = NA_real_,
    amber_previous = NA_real_,
    sites_total = dplyr::n_distinct(dfCurrent$GroupID),
    sites_flagged = dplyr::n_distinct(dfCurrent$GroupID[!is.na(absFlag) & absFlag >= 1]),
    sites_red = dplyr::n_distinct(dfCurrent$GroupID[!is.na(absFlag) & absFlag == 2]),
    escalated = NA_real_,
    new = NA_real_,
    improved = NA_real_
  )
  lSummary$sites_clear <- lSummary$sites_total - lSummary$sites_flagged

  if (bHasPrevious) {
    absPrevious <- abs(dfCurrent$Flag_Previous)
    absNow <- dplyr::coalesce(absFlag, 0)
    lSummary$red_previous <- sum(absPrevious == 2, na.rm = TRUE)
    lSummary$amber_previous <- sum(absPrevious == 1, na.rm = TRUE)
    lSummary$escalated <- sum(!is.na(absPrevious) & absNow > absPrevious)
    lSummary$improved <- sum(!is.na(absPrevious) & absNow < absPrevious)
    lSummary$new <- sum(is.na(absPrevious) & absNow > 0)
  }

  lSummary
}

#' @describeIn ReportV2 Study masthead with status chips and enrollment progress.
ReportV2_Masthead <- function(lSetup) {
  lStudy <- lSetup$lStudy
  vChips <- c(
    lStudy$status,
    paste("Snapshot", lSetup$SnapshotDate),
    if (!is.null(lStudy$phase)) paste("Phase", sub("^P", "", lStudy$phase)),
    lStudy$therapeutic_area
  )

  progress <- function(strLabel, numValue, numTarget) {
    if (is.na(numValue) || is.na(numTarget) || numTarget <= 0) {
      return(NULL)
    }
    numP <- min(numValue / numTarget, 1)
    htmltools::tags$div(
      htmltools::tags$div(class = "v2-stat-label", strLabel),
      htmltools::tags$div(
        class = "v2-stat-value",
        format(numValue, big.mark = ","),
        htmltools::tags$small(sprintf(
          " / %s \u00B7 %s%%",
          format(numTarget, big.mark = ","),
          round(100 * numValue / numTarget, 1)
        ))
      ),
      htmltools::tags$div(
        class = "v2-bar",
        htmltools::tags$span(style = paste0("--p:", signif(numP, 4)))
      )
    )
  }

  htmltools::tags$header(
    class = "v2-card v2-masthead v2-reveal",
    id = "v2-summary",
    htmltools::tags$div(
      class = "v2-eyebrow",
      lapply(seq_along(vChips), function(i) {
        htmltools::tags$span(class = paste("v2-chip", if (i == 1) "live"), vChips[[i]])
      })
    ),
    htmltools::tags$h1(paste(lSetup$GroupLevel, "KRI Overview")),
    htmltools::tags$p(
      class = "v2-subtitle",
      htmltools::tags$b(lSetup$StudyLabel),
      if (!is.null(lStudy$protocol_title)) paste(" \u00B7", lStudy$protocol_title)
    ),
    htmltools::tags$div(
      class = "v2-progress-row",
      progress("Site activation", v2_num(lStudy$SiteCount), v2_num(lStudy$SiteTarget)),
      progress(
        "Participant enrollment",
        v2_num(lStudy$ParticipantCount),
        v2_num(lStudy$ParticipantTarget)
      )
    )
  )
}

#' @describeIn ReportV2 KPI cards with change versus the previous snapshot.
ReportV2_KPICards <- function(lSummary, strGroupLevel = "Site") {
  strGroups <- paste0(strGroupLevel, "s")
  delta <- function(numCurrent, numPrevious) {
    if (is.na(numPrevious)) {
      return(NULL)
    }
    numDelta <- numCurrent - numPrevious
    strClass <- if (numDelta > 0) "up-bad" else if (numDelta < 0) "down-good" else "flat"
    strText <- if (numDelta == 0) {
      "no change"
    } else {
      paste(if (numDelta > 0) "\u25B2" else "\u25BC", abs(numDelta))
    }
    htmltools::tagList(
      htmltools::tags$span(class = paste("v2-delta", strClass), strText),
      " vs prior snapshot"
    )
  }
  pct <- function(n) {
    if (lSummary$sites_total == 0) "0%" else paste0(round(100 * n / lSummary$sites_total), "%")
  }

  lCards <- list(
    list("Red KRIs", lSummary$red, "red", delta(lSummary$red, lSummary$red_previous)),
    list("Amber KRIs", lSummary$amber, "amber", delta(lSummary$amber, lSummary$amber_previous)),
    list(
      paste(strGroups, "with a red KRI"), lSummary$sites_red, "red",
      paste(pct(lSummary$sites_red), "of", lSummary$sites_total, tolower(strGroups))
    ),
    list(
      paste(strGroups, "without flags"), lSummary$sites_clear, "green",
      paste(lSummary$sites_flagged, tolower(strGroups), "with red or amber")
    )
  )

  htmltools::tags$div(
    class = "v2-kpis",
    lapply(seq_along(lCards), function(i) {
      lCard <- lCards[[i]]
      htmltools::tags$div(
        class = paste("v2-card v2-kpi v2-reveal", lCard[[3]]),
        style = sprintf("--d:%.2fs", 0.05 * i),
        htmltools::tags$div(class = "v2-kpi-label", lCard[[1]]),
        htmltools::tags$div(class = "v2-kpi-value", `data-count` = lCard[[2]], lCard[[2]]),
        htmltools::tags$div(class = "v2-kpi-foot", lCard[[4]])
      )
    })
  )
}

#' @describeIn ReportV2 Key takeaways and highest risk-score groups.
ReportV2_Takeaways <- function(lSummary, dfResults, dfMetrics, dfGroups) {
  dfCounts <- v2_metric_counts(dfResults, dfMetrics)
  dfTop <- dfCounts[1, ]
  strGroupLevel <- v2_group_level(dfMetrics)
  strGroups <- tolower(paste0(strGroupLevel, "s"))
  vLabels <- v2_group_labels(dfGroups, strGroupLevel)

  bullet <- function(strColor, ...) {
    htmltools::tags$li(
      htmltools::tags$span(class = paste("v2-dot", strColor)),
      htmltools::tags$span(...)
    )
  }

  lBullets <- list(
    bullet(
      "red",
      htmltools::tags$b(lSummary$red, "red"), " and ",
      htmltools::tags$b(lSummary$amber, "amber"), " KRI flags across ",
      htmltools::tags$b(lSummary$sites_flagged), " of ", lSummary$sites_total, " ", strGroups, "."
    ),
    if (nrow(dfTop) == 1 && (dfTop$red + dfTop$amber) > 0) {
      bullet(
        "red",
        htmltools::tags$b(dfTop$Metric), " drives the most risk with ",
        htmltools::tags$b(dfTop$red), " red and ", dfTop$amber, " amber ", strGroups, "."
      )
    },
    if (!is.na(lSummary$escalated)) {
      bullet(
        "amber",
        htmltools::tags$b(lSummary$escalated), " signals escalated, ",
        htmltools::tags$b(lSummary$new), " newly flagged and ",
        htmltools::tags$b(lSummary$improved), " improved since the previous snapshot."
      )
    },
    bullet(
      "green",
      htmltools::tags$b(lSummary$sites_clear), " ", strGroups, " have no red or amber KRIs."
    )
  )

  dfSRS <- dfResults[!v2_is_kri(dfResults$MetricID) & !is.na(dfResults$Score), ]
  if ("SnapshotDate" %in% names(dfSRS) && nrow(dfSRS) > 0) {
    dfSRS <- dfSRS[dfSRS$SnapshotDate == max(dfSRS$SnapshotDate), ]
  }
  riskCard <- NULL
  if (nrow(dfSRS) > 0) {
    dfSRS <- dfSRS %>%
      dplyr::arrange(dplyr::desc(.data$Score)) %>%
      utils::head(6)
    numMax <- max(dfSRS$Score)
    riskCard <- htmltools::tags$div(
      class = "v2-card v2-insight v2-reveal",
      htmltools::tags$h3("Highest site risk scores"),
      htmltools::tags$div(
        class = "v2-hot-list",
        lapply(seq_len(nrow(dfSRS)), function(i) {
          htmltools::tags$button(
            type = "button",
            class = "v2-hot",
            `data-site` = dfSRS$GroupID[i],
            htmltools::tags$span(
              htmltools::tags$b(class = "v2-mono", dfSRS$GroupID[i]),
              " ",
              htmltools::tags$span(class = "v2-muted", unname(vLabels[dfSRS$GroupID[i]]) %|% "")
            ),
            htmltools::tags$span(
              class = "v2-srs",
              htmltools::tags$span(style = sprintf("width:%.1f%%", 100 * dfSRS$Score[i] / numMax))
            ),
            htmltools::tags$span(class = "v2-num", sprintf("%.1f", dfSRS$Score[i]))
          )
        })
      )
    )
  }

  htmltools::tags$div(
    class = paste("v2-insights", if (is.null(riskCard)) "single"),
    htmltools::tags$div(
      class = "v2-card v2-insight v2-reveal",
      htmltools::tags$h3("Key takeaways"),
      htmltools::tags$ul(lBullets)
    ),
    riskCard
  )
}

`%|%` <- function(x, y) {
  if (length(x) == 0 || is.na(x)) y else x
}

#' @describeIn ReportV2 Sidebar navigation with per-KRI flag badges.
ReportV2_Nav <- function(dfResults, dfMetrics) {
  dfCounts <- v2_metric_counts(dfResults, dfMetrics)
  strGroupLevel <- v2_group_level(dfMetrics)
  link <- function(strHref, strLabel, badges = NULL) {
    htmltools::tags$a(
      href = strHref,
      htmltools::tags$span(class = "v2-nav-label", strLabel),
      htmltools::tags$span(class = "v2-pip", badges)
    )
  }
  group <- function(strTitle, ...) {
    htmltools::tags$div(
      class = "v2-nav-group",
      htmltools::tags$div(class = "v2-nav-title", strTitle),
      ...
    )
  }

  htmltools::tags$nav(
    class = "v2-sidebar",
    id = "v2-sidebar",
    `aria-label` = "Report sections",
    group(
      "Overview",
      link("#v2-summary", "Summary"),
      link("#v2-overview", paste(strGroupLevel, "overview")),
      if ("Flag_Previous" %in% names(dfResults)) link("#v2-changes", "Flag changes")
    ),
    group(
      "Key risk indicators",
      lapply(seq_len(nrow(dfCounts)), function(i) {
        link(
          paste0("#kri-", dfCounts$MetricID[i]),
          dfCounts$Metric[i],
          v2_badges(dfCounts$red[i], dfCounts$amber[i])
        )
      })
    ),
    group("Reference", link("#v2-reference", "Metric definitions"))
  )
}

#' @describeIn ReportV2 Flag changes rendered as categorized cards.
ReportV2_FlagChanges <- function(dfResults, dfMetrics, dfGroups) {
  vRequired <- c("Flag_Previous", "Score_Previous", "Numerator_Previous", "Denominator_Previous")
  if (!all(vRequired %in% names(dfResults))) {
    return(NULL)
  }

  vLabels <- v2_group_labels(dfGroups, unique(dfMetrics$GroupLevel)[1])
  vMetricNames <- stats::setNames(dfMetrics$Metric, dfMetrics$MetricID)
  vAbbr <- stats::setNames(dfMetrics$Abbreviation, dfMetrics$MetricID)

  dfChanged <- v2_current(dfResults) %>%
    dplyr::filter(
      (is.na(.data$Flag) & !is.na(.data$Flag_Previous)) |
        (!is.na(.data$Flag) & is.na(.data$Flag_Previous)) |
        (.data$Flag != .data$Flag_Previous)
    ) %>%
    dplyr::filter(!(is.na(.data$Flag_Previous) & .data$Flag == 0)) %>%
    dplyr::mutate(
      absNow = dplyr::coalesce(abs(.data$Flag), 0),
      absPrev = abs(.data$Flag_Previous),
      cat = dplyr::case_when(
        is.na(.data$absPrev) ~ "new",
        .data$absNow > .data$absPrev ~ "escalated",
        .data$absNow < .data$absPrev ~ "improved",
        TRUE ~ "flipped"
      )
    ) %>%
    dplyr::arrange(dplyr::desc(.data$absNow), dplyr::desc(dplyr::coalesce(.data$absPrev, 0)))

  vCats <- c(
    escalated = "Escalated",
    new = "Newly flagged",
    improved = "Improved",
    flipped = "Direction flip"
  )
  vCats <- vCats[names(vCats) %in% dfChanged$cat]

  stat_row <- function(strLabel, prev, cur, digits = 2, bInteger = FALSE) {
    fmt <- function(x) {
      if (is.na(x)) "\u2013" else if (bInteger) format(x) else format(round(x, digits), nsmall = digits)
    }
    htmltools::tags$tr(
      htmltools::tags$td(strLabel),
      htmltools::tags$td(fmt(prev)),
      htmltools::tags$td(fmt(cur)),
      htmltools::tags$td(
        if (is.na(prev) || is.na(cur)) "\u2013" else if (bInteger) sprintf("%+d", as.integer(cur - prev)) else v2_signed(cur - prev, digits)
      )
    )
  }

  cards <- lapply(seq_len(nrow(dfChanged)), function(i) {
    row <- dfChanged[i, ]
    htmltools::tags$article(
      class = "v2-change",
      `data-cat` = row$cat,
      `data-site` = row$GroupID,
      tabindex = "0",
      htmltools::tags$div(
        class = "v2-change-head",
        htmltools::tags$span(class = "v2-mono", v2_group_label(row$GroupID, vLabels)),
        htmltools::tags$span(class = "v2-badge neutral", unname(vAbbr[row$MetricID]) %|% row$MetricID)
      ),
      htmltools::tags$div(class = "v2-change-metric", unname(vMetricNames[row$MetricID]) %|% row$MetricID),
      htmltools::tags$div(
        class = "v2-change-head",
        htmltools::tags$span(
          class = "v2-transition",
          v2_flag_tag(row$Flag_Previous),
          htmltools::tags$span(`aria-hidden` = "true", "\u2192"),
          v2_flag_tag(row$Flag)
        ),
        htmltools::tags$span(
          class = "v2-muted",
          "Score ", htmltools::tags$b(if (is.na(row$Score)) "\u2013" else sprintf("%.2f", row$Score))
        )
      ),
      htmltools::tags$div(
        class = "v2-change-detail",
        htmltools::tags$div(
          htmltools::tags$table(
            class = "v2-detail-table",
            htmltools::tags$thead(htmltools::tags$tr(
              htmltools::tags$th(""), htmltools::tags$th("Previous"),
              htmltools::tags$th("Current"), htmltools::tags$th("\u0394")
            )),
            htmltools::tags$tbody(
              stat_row("Score", row$Score_Previous, row$Score),
              stat_row("Numerator", row$Numerator_Previous, row$Numerator, bInteger = TRUE),
              stat_row("Denominator", row$Denominator_Previous, row$Denominator, bInteger = TRUE),
              if ("Metric_Previous" %in% names(row)) stat_row("Metric", row$Metric_Previous, row$Metric, digits = 4)
            )
          )
        )
      )
    )
  })

  htmltools::tags$section(
    id = "v2-changes",
    htmltools::tags$div(
      class = "v2-section-head",
      htmltools::tags$div(
        htmltools::tags$h2("Flag changes"),
        htmltools::tags$p(
          class = "v2-section-sub",
          sprintf(
            "%d risk signal%s changed flag since the previous snapshot.",
            nrow(dfChanged), if (nrow(dfChanged) == 1) "" else "s"
          )
        )
      )
    ),
    htmltools::tags$div(
      class = "v2-card v2-reveal",
      htmltools::tags$div(
        class = "v2-toolbar",
        htmltools::tags$div(
          class = "v2-seg v2-change-tabs",
          role = "tablist",
          lapply(seq_along(vCats), function(i) {
            htmltools::tags$button(
              type = "button",
              role = "tab",
              `data-cat` = names(vCats)[i],
              `aria-selected` = tolower(i == 1),
              vCats[[i]], " ",
              htmltools::tags$span(class = "v2-badge neutral", sum(dfChanged$cat == names(vCats)[i]))
            )
          })
        ),
        htmltools::tags$span(class = "v2-section-sub", "Select a card for snapshot details")
      ),
      if (nrow(dfChanged) == 0) {
        htmltools::tags$div(class = "v2-empty", "No flags changed since the previous snapshot.")
      } else {
        htmltools::tagList(
          htmltools::tags$div(class = "v2-changes-grid", cards),
          htmltools::tags$div(class = "v2-more")
        )
      }
    )
  )
}

#' @describeIn ReportV2 A collapsible card holding the charts for one KRI.
ReportV2_MetricCard <- function(lCharts, lMetric, dfResults) {
  dfCurrent <- v2_current(dfResults)
  absFlag <- abs(dfCurrent$Flag[dfCurrent$MetricID == lMetric$MetricID])
  intRed <- sum(absFlag == 2, na.rm = TRUE)
  intAmber <- sum(absFlag == 1, na.rm = TRUE)
  intN <- length(absFlag)
  strSeverity <- if (intRed > 0) "has-red" else if (intAmber > 0) "has-amber" else NULL
  bCollapsed <- intRed == 0 && intAmber == 0
  vKeys <- names(lCharts)

  tabs <- lapply(seq_along(lCharts), function(i) {
    strLabel <- attr(lCharts[[i]], "output_label", exact = TRUE) %||% vKeys[i]
    htmltools::tags$button(
      type = "button",
      role = "tab",
      class = "v2-tab",
      `data-pane` = vKeys[i],
      `aria-selected` = tolower(i == 1),
      htmltools::HTML(strLabel)
    )
  })
  panes <- lapply(seq_along(lCharts), function(i) {
    htmltools::tags$div(
      class = paste("v2-pane", if (i == 1) "active"),
      `data-pane` = vKeys[i],
      htmltools::tags$div(
        class = paste("gsm-widget", lMetric$MetricID, vKeys[i]),
        lCharts[[i]]
      )
    )
  })

  htmltools::tags$article(
    class = paste(c("v2-card", "v2-metric", strSeverity, if (bCollapsed) "collapsed"), collapse = " "),
    id = paste0("kri-", lMetric$MetricID),
    htmltools::tags$div(
      class = "v2-metric-head",
      role = "button",
      tabindex = "0",
      `aria-expanded` = tolower(!bCollapsed),
      htmltools::tags$div(class = "v2-metric-abbr", lMetric$Abbreviation %||% ""),
      htmltools::tags$div(
        htmltools::tags$h3(class = "v2-metric-title", lMetric$Metric),
        htmltools::tags$div(
          class = "v2-metric-def",
          paste(lMetric$Numerator, "\u00F7", lMetric$Denominator),
          if (!is.null(lMetric$Model) && !is.na(lMetric$Model)) paste(" \u00B7", lMetric$Model),
          if (!is.null(lMetric$Threshold) && !is.na(lMetric$Threshold)) {
            htmltools::tagList(" \u00B7 thresholds ", htmltools::tags$code(lMetric$Threshold))
          }
        )
      ),
      htmltools::tags$div(
        class = "v2-metric-meta",
        if (intRed > 0) htmltools::tags$span(class = "v2-badge red", paste(intRed, "red")),
        if (intAmber > 0) htmltools::tags$span(class = "v2-badge amber", paste(intAmber, "amber")),
        if (bCollapsed) htmltools::tags$span(class = "v2-badge green", "No flags"),
        htmltools::tags$span(class = "v2-badge neutral", paste(intN, "groups")),
        htmltools::HTML('<svg class="v2-chev" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>')
      )
    ),
    htmltools::tags$div(
      class = "v2-metric-body",
      htmltools::tags$div(
        htmltools::tags$div(class = "v2-tabs", role = "tablist", tabs),
        htmltools::tags$div(class = "v2-panes", panes)
      )
    )
  )
}

#' @describeIn ReportV2 Reference cards with KRI definitions.
ReportV2_MetricReference <- function(dfMetrics) {
  dfKRI <- dfMetrics[v2_is_kri(dfMetrics$MetricID), ]
  field <- function(strLabel, value) {
    if (is.null(value) || is.na(value)) {
      return(NULL)
    }
    htmltools::tagList(htmltools::tags$dt(strLabel), htmltools::tags$dd(value))
  }

  htmltools::tags$section(
    id = "v2-reference",
    htmltools::tags$div(
      class = "v2-section-head",
      htmltools::tags$div(
        htmltools::tags$h2("Metric definitions"),
        htmltools::tags$p(class = "v2-section-sub", "Numerator, denominator, statistical model and flagging thresholds.")
      )
    ),
    htmltools::tags$div(
      class = "v2-ref",
      lapply(seq_len(nrow(dfKRI)), function(i) {
        lMetric <- as.list(dfKRI[i, ])
        htmltools::tags$div(
          class = "v2-card",
          htmltools::tags$h4(
            htmltools::tags$span(class = "v2-badge neutral v2-mono", lMetric$Abbreviation %||% ""),
            lMetric$Metric
          ),
          htmltools::tags$dl(
            field("Numerator", lMetric$Numerator),
            field("Denominator", lMetric$Denominator),
            field("Model", lMetric$Model),
            field("Thresholds", lMetric$Threshold)
          )
        )
      })
    )
  )
}

#' @describeIn ReportV2 Sticky top bar with the global group search.
ReportV2_Topbar <- function(lSetup, dfResults, dfGroups) {
  dfCurrent <- v2_current(dfResults)
  vLabels <- v2_group_labels(dfGroups, lSetup$GroupLevel)
  dfSites <- dfCurrent %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarise(
      red = sum(abs(.data$Flag) == 2, na.rm = TRUE),
      amber = sum(abs(.data$Flag) == 1, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(label = unname(vLabels[.data$GroupID])) %>%
    dplyr::arrange(dplyr::desc(.data$red), dplyr::desc(.data$amber), .data$GroupID)

  htmltools::tagList(
    htmltools::tags$script(
      type = "application/json",
      id = "v2-sites",
      htmltools::HTML(jsonlite::toJSON(dfSites, na = "null"))
    ),
    htmltools::tags$div(
      class = "v2-topbar",
      id = "v2-topbar",
      htmltools::tags$button(type = "button", class = "v2-icon-btn", id = "v2-nav-toggle", `aria-label` = "Toggle navigation", "\u2630"),
      htmltools::tags$div(
        class = "v2-brand",
        htmltools::tags$span(class = "v2-brand-mark", "gsm"),
        "KRI Report",
        htmltools::tags$span(class = "v2-crumb", paste("/", lSetup$StudyLabel))
      ),
      htmltools::tags$div(class = "v2-spacer"),
      htmltools::tags$label(class = "v2-picker-label", `for` = "v2-site-input", paste("Highlight", tolower(lSetup$GroupLevel))),
      htmltools::tags$div(
        class = "v2-combo",
        id = "v2-combo",
        htmltools::tags$input(
          id = "v2-site-input",
          class = "v2-site-input",
          role = "combobox",
          `aria-expanded` = "false",
          `aria-controls` = "v2-site-list",
          autocomplete = "off",
          placeholder = "Search ID or investigator\u2026  ( / )"
        ),
        htmltools::tags$button(type = "button", class = "v2-clear", id = "v2-site-clear", `aria-label` = "Clear highlighted group", "\u00D7"),
        htmltools::tags$div(class = "v2-combo-list", id = "v2-site-list", role = "listbox")
      ),
      htmltools::tags$button(type = "button", class = "v2-icon-btn", id = "v2-theme", `aria-label` = "Toggle dark mode", "\u25D0"),
      htmltools::tags$button(type = "button", class = "v2-icon-btn", onclick = "window.print()", "Print")
    )
  )
}

#' @describeIn ReportV2 Stylesheet and script for the v2 template.
ReportV2_Dependencies <- function() {
  htmltools::htmlDependency(
    name = "gsm-report-v2",
    version = as.character(utils::packageVersion("gsm.kri")),
    src = "report/v2",
    package = "gsm.kri",
    stylesheet = "report_v2.css",
    script = "report_v2.js"
  )
}
