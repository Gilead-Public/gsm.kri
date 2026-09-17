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
#' Built on [gsm.vizr::bars()], the JS `bars` module from `gsm.viz`.
#'
#' @param dfDistribution `data.frame` output of [AEGrading_SiteDistribution()].
#' @param dfFlagged `data.frame` optional site-level results with `GroupID` and
#'   `Flag` columns (for example `Analysis_Flagged` from `kri0016`). Flagged
#'   sites are called out on the axis. Default: `NULL`.
#' @param strTitle `character` plot title.
#'
#' @return A `bars` htmlwidget.
#'
#' @export
Visualize_GradeBySite <- function(
  dfDistribution,
  dfFlagged = NULL,
  strTitle = "AE severity grade distribution by site"
) {
  vGradeColors <- c(
    "Grade 1" = "#FFFFB2",
    "Grade 2" = "#FECC5C",
    "Grade 3" = "#FD8D3C",
    "Grade 4" = "#F03B20",
    "Grade 5" = "#BD0026"
  )

  dfOrder <- dfDistribution %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarize(
      HighGrade = sum(.data$Proportion[.data$Grade >= 3]),
      .groups = "drop"
    ) %>%
    dplyr::arrange(.data$HighGrade)

  nStudyHigh <- dfDistribution %>%
    dplyr::distinct(.data$Grade, .data$StudyProportion) %>%
    dplyr::filter(.data$Grade >= 3) %>%
    dplyr::pull(.data$StudyProportion) %>%
    sum()

  vFlagged <- character(0)
  if (!is.null(dfFlagged) && nrow(dfFlagged) > 0) {
    vFlagged <- dfFlagged %>%
      dplyr::filter(!is.na(.data$Flag), .data$Flag != 0) %>%
      dplyr::pull(.data$GroupID) %>%
      unique()
  }

  # Flag on the axis label itself; gsm.viz has no separate axis-annotation hook.
  FlagLabel <- function(x) {
    ifelse(x %in% vFlagged, paste0("\u25b6 ", x), x)
  }

  dfPlot <- dfDistribution %>%
    dplyr::mutate(
      GroupLabel = FlagLabel(.data$GroupID),
      Grade = paste("Grade", .data$Grade)
    )
  vSiteOrder <- FlagLabel(dfOrder$GroupID)

  gsm.vizr::bars(
    data = dfPlot,
    spec = gsm.vizr::bars_spec(
      x = "GroupLabel",
      y = "Count",
      fill = "Grade",
      orientation = "horizontal",
      position = "stack",
      stat = "percent",
      scales = list(
        x = list(label = NULL, order = vSiteOrder),
        y = list(label = "Proportion of adverse events"),
        fill = list(colors = as.list(vGradeColors))
      ),
      labels = list(
        title = strTitle,
        captions = paste0(
          "Sorted by proportion of Grade 3+ events. Dashed line = study-wide Grade 3+ proportion (",
          round(nStudyHigh * 100, 1), "%). ",
          if (length(vFlagged)) "Sites marked \u25b6 are flagged by the grading KRI." else ""
        )
      ),
      annotations = list(
        referenceLines = list(list(
          value = (1 - nStudyHigh) * 100,
          label = "Study-wide Grade 3+",
          color = "#1a1a1a",
          lineDash = c(4, 4)
        ))
      ),
      tooltip = list(format = "percent+count"),
      theme = list(dynamicSizing = TRUE, pxPerCategory = 22)
    ),
    minHeight = 500
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
