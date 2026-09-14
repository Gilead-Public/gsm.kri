#' AE severity grading distribution by site
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Summarizes the CTCAE grade distribution of adverse events for each site and
#' compares it to the study-wide distribution. This is the descriptive backbone
#' of the AE grading report and the visual companion to the `kri0016` /
#' `kri0017` grading KRIs.
#'
#' @param dfAE `data.frame` mapped AE data. Must contain `subjid` and `aetoxgr`.
#' @param dfSubj `data.frame` mapped subject data. Must contain `subjid` and the
#'   grouping column named in `strGroupCol`.
#' @param strGroupCol `character` site identifier column in `dfSubj`. Default: `"invid"`.
#' @param nMinAE `numeric` minimum number of graded AEs for a site to be included.
#'   Default: `20`.
#'
#' @return `data.frame` with one row per site/grade combination and columns
#'   `GroupID`, `Grade`, `Count`, `SiteTotal`, `Proportion`, `StudyProportion`.
#'
#' @export
AEGrading_SiteDistribution <- function(
  dfAE,
  dfSubj,
  strGroupCol = "invid",
  nMinAE = 20
) {
  dfGraded <- dfAE %>%
    dplyr::mutate(Grade = suppressWarnings(as.integer(.data$aetoxgr))) %>%
    dplyr::filter(.data$Grade %in% 1:5) %>%
    dplyr::inner_join(
      dfSubj %>%
        dplyr::select(dplyr::all_of(c("subjid", strGroupCol))) %>%
        dplyr::rename(GroupID = dplyr::all_of(strGroupCol)),
      by = "subjid"
    ) %>%
    dplyr::filter(!is.na(.data$GroupID))

  dfStudy <- dfGraded %>%
    dplyr::count(.data$Grade, name = "StudyCount") %>%
    dplyr::mutate(StudyProportion = .data$StudyCount / sum(.data$StudyCount)) %>%
    dplyr::select("Grade", "StudyProportion")

  dfSite <- dfGraded %>%
    dplyr::count(.data$GroupID, name = "SiteTotal") %>%
    dplyr::filter(.data$SiteTotal >= nMinAE)

  dfGraded %>%
    dplyr::semi_join(dfSite, by = "GroupID") %>%
    dplyr::count(.data$GroupID, .data$Grade, name = "Count") %>%
    tidyr::complete(
      .data$GroupID,
      Grade = 1:5,
      fill = list(Count = 0)
    ) %>%
    dplyr::left_join(dfSite, by = "GroupID") %>%
    dplyr::left_join(dfStudy, by = "Grade") %>%
    dplyr::mutate(Proportion = .data$Count / .data$SiteTotal) %>%
    dplyr::arrange(.data$GroupID, .data$Grade)
}

#' Plot the AE grade distribution by site
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Renders a 100% stacked bar chart of the CTCAE grade mix at each site, sorted
#' by the proportion of high-grade (Grade 3+) events. A dashed reference line
#' marks the study-wide high-grade proportion, so sites whose bars break away
#' from that line are the ones grading differently from the rest of the study.
#'
#' @param dfDistribution `data.frame` output of [AEGrading_SiteDistribution()].
#' @param dfFlagged `data.frame` optional site-level results with `GroupID` and
#'   `Flag` columns (for example `Analysis_Flagged` from `kri0016`). Flagged
#'   sites are called out on the axis. Default: `NULL`.
#' @param strTitle `character` plot title.
#'
#' @return `ggplot` object.
#'
#' @export
Visualize_GradeBySite <- function(
  dfDistribution,
  dfFlagged = NULL,
  strTitle = "AE severity grade distribution by site"
) {
  vGradeColors <- c(
    "1" = "#FFFFB2",
    "2" = "#FECC5C",
    "3" = "#FD8D3C",
    "4" = "#F03B20",
    "5" = "#BD0026"
  )

  dfOrder <- dfDistribution %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarize(
      HighGrade = sum(.data$Proportion[.data$Grade >= 3]),
      SiteTotal = dplyr::first(.data$SiteTotal),
      .groups = "drop"
    ) %>%
    dplyr::arrange(.data$HighGrade)

  nStudyHigh <- dfDistribution %>%
    dplyr::distinct(.data$Grade, .data$StudyProportion) %>%
    dplyr::filter(.data$Grade >= 3) %>%
    dplyr::pull(.data$StudyProportion) %>%
    sum()

  dfPlot <- dfDistribution %>%
    dplyr::mutate(
      GroupID = factor(.data$GroupID, levels = dfOrder$GroupID),
      Grade = factor(.data$Grade, levels = 5:1)
    )

  vFlagged <- character(0)
  if (!is.null(dfFlagged) && nrow(dfFlagged) > 0) {
    vFlagged <- dfFlagged %>%
      dplyr::filter(!is.na(.data$Flag), .data$Flag != 0) %>%
      dplyr::pull(.data$GroupID) %>%
      unique()
  }

  if (length(vFlagged)) {
    levels(dfPlot$GroupID) <- ifelse(
      levels(dfPlot$GroupID) %in% vFlagged,
      paste0("\u25b6 ", levels(dfPlot$GroupID)),
      levels(dfPlot$GroupID)
    )
  }

  ggplot2::ggplot(
    dfPlot,
    ggplot2::aes(x = .data$GroupID, y = .data$Proportion, fill = .data$Grade)
  ) +
    ggplot2::geom_col(width = 0.85) +
    ggplot2::geom_hline(
      yintercept = 1 - nStudyHigh,
      linetype = "dashed",
      color = "#1a1a1a",
      linewidth = 0.5
    ) +
    ggplot2::scale_fill_manual(
      values = vGradeColors,
      breaks = as.character(1:5),
      labels = paste("Grade", 1:5),
      name = NULL
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent, expand = c(0, 0)) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = strTitle,
      subtitle = paste0(
        "Sorted by proportion of Grade 3+ events. Dashed line = study-wide Grade 3+ proportion (",
        round(nStudyHigh * 100, 1), "%). ",
        if (length(vFlagged)) "Sites marked \u25b6 are flagged by the grading KRI." else ""
      ),
      x = NULL,
      y = "Proportion of adverse events"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.y = ggplot2::element_text(size = 7, colour = "grey25"),
      panel.grid.major.y = ggplot2::element_blank(),
      legend.position = "top",
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30")
    )
}

#' Report_AEGrading function
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates an AE severity grading report: the study-wide grade distribution,
#' a grade-by-site stacked bar chart, and the sites flagged by the grading
#' metric.
#'
#' @param dfResults `data.frame` Reporting results data. Filtered internally to
#'   site-level rows for `strMetricID`; used to mark and list flagged sites. When
#'   `NULL` the chart still renders, without flags.
#' @param lListings `list` containing `Mapped_AE` and `Mapped_SUBJ`.
#' @param strMetricID `string` MetricID of the grading metric to report on.
#'   Default: `"Analysis_kri0016"` (High-Grade AE Proportion). Use
#'   `"Analysis_kri0017"` for the Low-Grade AE Proportion metric.
#' @param nMinAE `numeric` Minimum number of graded AEs for a site to appear in
#'   the chart. Default: 20.
#' @param strOutputDir `string` Output directory. Default: working directory.
#' @param strOutputFile `string` Output filename. Default: `Report_AEGrading.html`.
#' @param strInputPath `string` Path to the template `Rmd`.
#'
#' @return File path of the saved report HTML, returned invisibly.
#'
#' @keywords KRI report
#' @export
Report_AEGrading <- function(
  dfResults = NULL,
  lListings = NULL,
  strMetricID = "Analysis_kri0016",
  nMinAE = 20,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  strInputPath = system.file(
    "report",
    "Report_AEGrading.Rmd",
    package = "gsm.kri"
  )
) {
  rlang::check_installed("rmarkdown", reason = "to run `Report_AEGrading()`")
  rlang::check_installed("knitr", reason = "to run `Report_AEGrading()`")

  gsm.core::stop_if(
    cnd = !(is.list(lListings) &&
      all(c("Mapped_AE", "Mapped_SUBJ") %in% names(lListings))),
    message = "lListings must contain `Mapped_AE` and `Mapped_SUBJ`"
  )

  gsm.core::stop_if(
    cnd = !(is.numeric(nMinAE) && length(nMinAE) == 1 && nMinAE > 0),
    message = "nMinAE must be a positive number"
  )

  if (is.null(strOutputFile)) {
    strOutputFile <- "Report_AEGrading.html"
  }

  gsm.kri::RenderRmd(
    strInputPath = strInputPath,
    strOutputFile = strOutputFile,
    strOutputDir = strOutputDir,
    lParams = list(
      dfResults = dfResults,
      lListings = lListings,
      strMetricID = strMetricID,
      nMinAE = nMinAE
    )
  )
}
