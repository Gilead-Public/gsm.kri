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

# Inactive metrics (Active == FALSE) no longer generate risk signals; NA or a
# missing Active column means active, matching MakeWeights() and Report_KRI.Rmd.
v2_inactive_ids <- function(dfMetrics) {
  if (is.null(dfMetrics) || !"Active" %in% names(dfMetrics)) {
    return(character())
  }
  dfMetrics$MetricID[dfMetrics$Active %in% FALSE]
}

v2_current <- function(dfResults, dfMetrics = NULL) {
  if ("SnapshotDate" %in% names(dfResults) && nrow(dfResults) > 0) {
    dfResults <- dfResults[dfResults$SnapshotDate == max(dfResults$SnapshotDate), ]
  }
  dfResults[
    v2_is_kri(dfResults$MetricID) &
      !dfResults$MetricID %in% v2_inactive_ids(dfMetrics),
  ]
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

# Active KRIs sorted by severity, followed by inactive KRIs (whose flags are not counted).
v2_metric_counts <- function(dfResults, dfMetrics) {
  dfCurrent <- v2_current(dfResults, dfMetrics)
  vInactive <- v2_inactive_ids(dfMetrics)
  dfMetrics[v2_is_kri(dfMetrics$MetricID), ] %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      inactive = .data$MetricID %in% vInactive,
      red = sum(abs(dfCurrent$Flag[dfCurrent$MetricID == .data$MetricID]) == 2, na.rm = TRUE),
      amber = sum(abs(dfCurrent$Flag[dfCurrent$MetricID == .data$MetricID]) == 1, na.rm = TRUE),
      n = sum(dfCurrent$MetricID == .data$MetricID)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(.data$inactive, dplyr::desc(.data$red), dplyr::desc(.data$amber))
}

#' @describeIn ReportV2 Headline counts for the current snapshot.
ReportV2_Summary <- function(dfResults, dfMetrics = NULL) {
  dfCurrent <- v2_current(dfResults, dfMetrics)
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

#' @describeIn ReportV2 Key takeaways for the current snapshot.
ReportV2_Takeaways <- function(lSummary, dfResults, dfMetrics, dfGroups) {
  dfCounts <- v2_metric_counts(dfResults, dfMetrics)
  dfTop <- dfCounts[!dfCounts$inactive, ][1, ]
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
      htmltools::tags$b(lSummary$sites_flagged), paste0(" of ", lSummary$sites_total, " ", strGroups, ".")
    ),
    if (nrow(dfTop) == 1 && (dfTop$red + dfTop$amber) > 0) {
      bullet(
        "red",
        htmltools::tags$b(dfTop$Metric), " drives the most risk with ",
        htmltools::tags$b(dfTop$red), " red and ", dfTop$amber, paste0(" amber ", strGroups, ".")
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
      htmltools::tags$b(lSummary$sites_clear), paste0(" ", strGroups, " have no red or amber KRIs.")
    )
  )

  htmltools::tags$div(
    class = "v2-card v2-insight v2-reveal",
    htmltools::tags$h3("Key takeaways"),
    htmltools::tags$ul(lBullets)
  )
}

`%|%` <- function(x, y) {
  if (length(x) == 0 || is.na(x)) y else x
}

#' @describeIn ReportV2 KRI list with per-KRI flag badges (Metrics tab).
ReportV2_Nav <- function(dfResults, dfMetrics) {
  dfCounts <- v2_metric_counts(dfResults, dfMetrics)
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
    class = "v2-card v2-metric-nav",
    id = "v2-metric-nav",
    `aria-label` = "Key risk indicators",
    group(
      "Key risk indicators",
      lapply(which(!dfCounts$inactive), function(i) {
        link(
          paste0("#kri-", dfCounts$MetricID[i]),
          dfCounts$Metric[i],
          v2_badges(dfCounts$red[i], dfCounts$amber[i])
        )
      })
    ),
    if (any(dfCounts$inactive)) {
      group(
        "Inactive",
        lapply(which(dfCounts$inactive), function(i) {
          link(
            paste0("#kri-", dfCounts$MetricID[i]),
            dfCounts$Metric[i],
            htmltools::tags$span(class = "v2-badge inactive", "Inactive")
          )
        })
      )
    },
    group("Reference", link("#v2-reference", "Metric definitions"))
  )
}

#' @describeIn ReportV2 Flag changes grouped by site or by KRI, with a perspective switch.
ReportV2_FlagChanges <- function(dfResults, dfMetrics, dfGroups) {
  vRequired <- c("Flag_Previous", "Score_Previous", "Numerator_Previous", "Denominator_Previous")
  if (!all(vRequired %in% names(dfResults))) {
    return(NULL)
  }

  strGroupLevel <- v2_group_level(dfMetrics)
  vLabels <- v2_group_labels(dfGroups, strGroupLevel)
  vMetricNames <- stats::setNames(dfMetrics$Metric, dfMetrics$MetricID)
  vAbbr <- stats::setNames(dfMetrics$Abbreviation, dfMetrics$MetricID)
  vSRS <- v2_site_srs(dfResults)
  # History mode needs at least two snapshots.
  lHist <- v2_flag_history(dfResults)
  bHistory <- length(lHist$dates) >= 2

  dfChanged <- v2_current(dfResults, dfMetrics) %>%
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
      ),
      srs = unname(vSRS[.data$GroupID])
    ) %>%
    dplyr::arrange(dplyr::desc(.data$absNow), dplyr::desc(dplyr::coalesce(.data$absPrev, 0)))

  vCats <- c(
    escalated = "Escalated",
    new = "Newly flagged",
    improved = "Improved",
    flipped = "Direction flip"
  )
  vCats <- vCats[names(vCats) %in% dfChanged$cat]

  fmt <- function(x, digits = 2) {
    if (is.na(x)) "\u2013" else formatC(x, format = "f", digits = digits)
  }
  change_row <- function(row, strView) {
    numDelta <- row$Score - row$Score_Previous
    strTitle <- paste0(
      "Score ", fmt(row$Score_Previous), " \u2192 ", fmt(row$Score),
      " \u00B7 Numerator ", fmt(row$Numerator_Previous, 0), " \u2192 ", fmt(row$Numerator, 0),
      " \u00B7 Denominator ", fmt(row$Denominator_Previous, 0), " \u2192 ", fmt(row$Denominator, 0)
    )
    htmltools::tags$li(
      class = "v2-change-row",
      `data-cat` = row$cat,
      `data-site` = row$GroupID,
      `data-metric` = row$MetricID,
      tabindex = "0",
      title = strTitle,
      if (strView == "site") {
        htmltools::tags$span(
          class = "v2-change-what",
          htmltools::tags$span(class = "v2-badge neutral v2-mono", unname(vAbbr[row$MetricID]) %|% row$MetricID),
          htmltools::tags$span(class = "v2-change-name", unname(vMetricNames[row$MetricID]) %|% row$MetricID)
        )
      } else {
        htmltools::tags$span(
          class = "v2-change-what",
          htmltools::tags$span(class = "v2-mono", row$GroupID),
          htmltools::tags$span(class = "v2-change-name v2-muted", unname(vLabels[row$GroupID]) %|% "")
        )
      },
      htmltools::tags$span(
        class = "v2-transition",
        v2_flag_tag(row$Flag_Previous),
        htmltools::tags$span(`aria-hidden` = "true", "\u2192"),
        v2_flag_tag(row$Flag)
      ),
      htmltools::tags$span(
        class = "v2-change-score",
        fmt(row$Score),
        if (!is.na(numDelta)) htmltools::tags$small(paste0(" ", v2_signed(numDelta)))
      ),
      if (bHistory) {
        strKey <- paste(row$GroupID, row$MetricID, sep = "\r")
        v2_history_strip(lHist$flags[[strKey]], lHist$scores[[strKey]], lHist$dates)
      }
    )
  }
  # Each perspective ends with a marker comment so it can be located in the rendered HTML.
  view_panel <- function(strView, groups, bHidden = FALSE) {
    htmltools::HTML(paste0(
      as.character(htmltools::tags$div(
        class = "v2-change-view",
        `data-view-panel` = strView,
        hidden = if (bHidden) NA,
        groups
      )),
      "<!--/", strView, "-->"
    ))
  }

  vSites <- dfChanged %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarise(srs = dplyr::first(.data$srs), n = dplyr::n(), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(dplyr::coalesce(.data$srs, -Inf)), dplyr::desc(.data$n), .data$GroupID)
  siteGroups <- lapply(seq_len(nrow(vSites)), function(i) {
    strSite <- vSites$GroupID[i]
    dfRows <- dfChanged[dfChanged$GroupID == strSite, ]
    htmltools::tags$section(
      class = "v2-change-group",
      `data-group` = strSite,
      htmltools::tags$button(
        type = "button",
        class = "v2-change-group-head",
        `data-open-site` = strSite,
        title = paste("Open", strSite, "in the", strGroupLevel, "tab"),
        htmltools::tags$span(
          htmltools::tags$b(class = "v2-mono", strSite), " ",
          htmltools::tags$span(class = "v2-muted", unname(vLabels[strSite]) %|% "")
        ),
        htmltools::tags$span(
          class = "v2-change-group-meta",
          if (!is.na(vSites$srs[i])) htmltools::tags$span(class = "v2-badge neutral", sprintf("Risk %.1f", vSites$srs[i])),
          htmltools::tags$span(class = "v2-badge neutral v2-group-count", nrow(dfRows))
        )
      ),
      htmltools::tags$ul(lapply(seq_len(nrow(dfRows)), function(j) change_row(dfRows[j, ], "site")))
    )
  })

  vKRIs <- dfChanged %>%
    dplyr::group_by(.data$MetricID) %>%
    dplyr::summarise(
      up = sum(.data$cat %in% c("escalated", "new")),
      n = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(.data$up), dplyr::desc(.data$n), .data$MetricID)
  kriGroups <- lapply(seq_len(nrow(vKRIs)), function(i) {
    strMetric <- vKRIs$MetricID[i]
    dfRows <- dfChanged[dfChanged$MetricID == strMetric, ] %>%
      dplyr::arrange(
        dplyr::desc(.data$absNow),
        dplyr::desc(dplyr::coalesce(.data$srs, -Inf))
      )
    htmltools::tags$section(
      class = "v2-change-group",
      `data-group` = strMetric,
      htmltools::tags$button(
        type = "button",
        class = "v2-change-group-head",
        `data-open-metric` = strMetric,
        title = "Open in the Metrics tab",
        htmltools::tags$span(
          htmltools::tags$span(class = "v2-badge neutral v2-mono", unname(vAbbr[strMetric]) %|% strMetric), " ",
          htmltools::tags$b(unname(vMetricNames[strMetric]) %|% strMetric)
        ),
        htmltools::tags$span(class = "v2-badge neutral v2-group-count", nrow(dfRows))
      ),
      htmltools::tags$ul(lapply(seq_len(nrow(dfRows)), function(j) change_row(dfRows[j, ], "kri")))
    )
  })

  vSegTip <- c(
    site = paste0("Group changes by ", tolower(strGroupLevel), ", highest risk score first."),
    latest = "Show each change as previous flag to current flag.",
    history = "Show each signal's flag in every snapshot, oldest on the left.",
    kri = "Group changes by KRI, most escalations first.",
    all = "Every flag change since the previous snapshot.",
    escalated = "Flag became more severe, e.g. amber to red.",
    new = "No flag in the previous snapshot; amber or red now.",
    improved = "Flag became less severe, e.g. red to amber or green.",
    flipped = "Same severity, opposite direction (above vs below expected)."
  )
  seg_button <- function(strAttr, strValue, strLabel, bSelected, intCount = NULL) {
    htmltools::tags$button(
      type = "button",
      role = "tab",
      `aria-selected` = tolower(bSelected),
      `data-view` = if (strAttr == "view") strValue,
      `data-cat` = if (strAttr == "cat") strValue,
      `data-mode` = if (strAttr == "mode") strValue,
      class = "v2-has-tip",
      title = vSegTip[[strValue]],
      strLabel,
      if (!is.null(intCount)) htmltools::tagList(" ", htmltools::tags$span(class = "v2-badge neutral", intCount))
    )
  }

  htmltools::tags$section(
    id = "v2-changes",
    htmltools::tags$div(
      class = "v2-section-head",
      htmltools::tags$div(
        htmltools::tags$h2("Flag changes"),
        htmltools::tags$p(
          class = "v2-section-sub",
          sprintf(
            "%d risk signal%s changed flag since the previous snapshot. Select a %s or KRI to open it.",
            nrow(dfChanged), if (nrow(dfChanged) == 1) "" else "s", tolower(strGroupLevel)
          )
        )
      )
    ),
    htmltools::tags$div(
      class = "v2-card v2-reveal",
      htmltools::tags$div(
        class = "v2-toolbar",
        htmltools::tags$div(
          class = "v2-seg v2-change-persp",
          role = "tablist",
          `aria-label` = "Perspective",
          seg_button("view", "site", paste("By", tolower(strGroupLevel)), TRUE),
          seg_button("view", "kri", "By KRI", FALSE)
        ),
        if (bHistory) {
          htmltools::tags$div(
            class = "v2-seg v2-change-mode",
            role = "tablist",
            `aria-label` = "Display",
            seg_button("mode", "latest", "Latest change", TRUE),
            seg_button("mode", "history", "History", FALSE)
          )
        },
        htmltools::tags$div(
          class = "v2-seg v2-change-tabs",
          role = "tablist",
          `aria-label` = "Change type",
          seg_button("cat", "all", "All", TRUE, nrow(dfChanged)),
          lapply(names(vCats), function(k) seg_button("cat", k, vCats[[k]], FALSE, sum(dfChanged$cat == k)))
        )
      ),
      if (bHistory) {
        htmltools::tags$div(
          class = "v2-hist-caption",
          sprintf(
            "Flag in each of %d snapshots, %s (left) to %s (right). Thick border: new or more severe than the snapshot before.",
            length(lHist$dates), lHist$dates[1], utils::tail(lHist$dates, 1)
          )
        )
      },
      if (nrow(dfChanged) == 0) {
        htmltools::tags$div(class = "v2-empty", "No flags changed since the previous snapshot.")
      } else {
        htmltools::tagList(
          view_panel("site", siteGroups),
          view_panel("kri", kriGroups, bHidden = TRUE),
          htmltools::tags$div(class = "v2-more")
        )
      }
    )
  )
}

#' @describeIn ReportV2 A collapsible card holding the charts for one KRI.
ReportV2_MetricCard <- function(lCharts, lMetric, dfResults) {
  dfCurrent <- v2_current(dfResults)
  bInactive <- isFALSE(as.logical(lMetric$Active %||% NA))
  absFlag <- abs(dfCurrent$Flag[dfCurrent$MetricID == lMetric$MetricID])
  intN <- length(absFlag)
  if (bInactive) absFlag <- absFlag[0]
  intRed <- sum(absFlag == 2, na.rm = TRUE)
  intAmber <- sum(absFlag == 1, na.rm = TRUE)
  strSeverity <- if (bInactive) "inactive" else if (intRed > 0) "has-red" else if (intAmber > 0) "has-amber" else NULL
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
        if (bInactive) {
          htmltools::tags$span(title = "Inactive metric: no longer generates risk signals", class = "v2-badge inactive", "Inactive")
        } else if (bCollapsed) {
          htmltools::tags$span(class = "v2-badge green", "No flags")
        },
        if (intN == 0) {
          htmltools::tags$span(class = "v2-badge neutral", "Not in latest snapshot")
        } else {
          htmltools::tags$span(class = "v2-badge neutral", paste(intN, tolower(paste0(lMetric$GroupLevel %||% "Group", "s"))))
        },
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
            lMetric$Metric,
            if (isFALSE(as.logical(lMetric$Active %||% NA))) {
              htmltools::tags$span(class = "v2-badge inactive", "Inactive")
            }
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
ReportV2_Topbar <- function(lSetup, dfResults, dfGroups, dfMetrics = NULL) {
  dfCurrent <- v2_current(dfResults)
  # Keep every group searchable, but count flags on active metrics only.
  dfCurrent$Flag[dfCurrent$MetricID %in% v2_inactive_ids(dfMetrics)] <- NA
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
