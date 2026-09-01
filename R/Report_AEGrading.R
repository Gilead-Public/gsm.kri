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

#' Term-level AE grading consistency
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Evaluates how each site grades the most frequently reported preferred terms
#' relative to the study as a whole. For every qualifying site/term pair the
#' function compares the site's high-grade (Grade 3+) proportion with the
#' study-wide high-grade proportion *for that same term*, so differences in a
#' site's AE mix cannot masquerade as a grading difference.
#'
#' A site/term pair is flagged when the absolute difference exceeds
#' `nDiffThreshold` and both volume thresholds are met.
#'
#' @param dfAE `data.frame` mapped AE data with `subjid`, `aetoxgr` and the term
#'   column named in `strTermCol`.
#' @param dfSubj `data.frame` mapped subject data with `subjid` and `strGroupCol`.
#' @param strGroupCol `character` site identifier column. Default: `"invid"`.
#' @param strTermCol `character` preferred term column. Default: `"mdrpt_nsv"`.
#' @param nTopTerms `numeric` number of most common preferred terms to evaluate.
#'   Default: `10`.
#' @param nMinTermStudy `numeric` minimum study-wide events for a term to be
#'   evaluated. Default: `50`.
#' @param nMinTermSite `numeric` minimum site-level events within a term for that
#'   site/term pair to be evaluated. Default: `10`.
#' @param nDiffThreshold `numeric` absolute difference in high-grade proportion
#'   required to flag a site/term pair. Default: `0.20`.
#' @param nZThreshold `numeric` absolute binomial z-score required for the
#'   supplementary `FlaggedZ` rule. The absolute-difference rule is insensitive to
#'   under-grading on terms whose study-wide high-grade proportion is already below
#'   `nDiffThreshold`; the z-score rule scales with volume and stays symmetric.
#'   Default: `3`.
#'
#' @return `data.frame` with one row per evaluated site/term pair.
#'
#' @export
AEGrading_TermConsistency <- function(
  dfAE,
  dfSubj,
  strGroupCol = "invid",
  strTermCol = "mdrpt_nsv",
  nTopTerms = 10,
  nMinTermStudy = 50,
  nMinTermSite = 10,
  nDiffThreshold = 0.20,
  nZThreshold = 3
) {
  dfGraded <- dfAE %>%
    dplyr::mutate(
      Grade = suppressWarnings(as.integer(.data$aetoxgr)),
      Term = .data[[strTermCol]]
    ) %>%
    dplyr::filter(.data$Grade %in% 1:5, !is.na(.data$Term)) %>%
    dplyr::inner_join(
      dfSubj %>%
        dplyr::select(dplyr::all_of(c("subjid", strGroupCol))) %>%
        dplyr::rename(GroupID = dplyr::all_of(strGroupCol)),
      by = "subjid"
    ) %>%
    dplyr::filter(!is.na(.data$GroupID))

  dfTerms <- dfGraded %>%
    dplyr::count(.data$Term, name = "StudyN") %>%
    dplyr::filter(.data$StudyN >= nMinTermStudy) %>%
    dplyr::arrange(dplyr::desc(.data$StudyN)) %>%
    utils::head(nTopTerms)

  if (nrow(dfTerms) == 0) {
    return(dfGraded[0, ] %>% dplyr::mutate(Term = character(0)))
  }

  dfStudyTerm <- dfGraded %>%
    dplyr::semi_join(dfTerms, by = "Term") %>%
    dplyr::group_by(.data$Term) %>%
    dplyr::summarize(
      StudyN = dplyr::n(),
      StudyHighGrade = mean(.data$Grade >= 3),
      .groups = "drop"
    )

  dfGraded %>%
    dplyr::semi_join(dfTerms, by = "Term") %>%
    dplyr::group_by(.data$GroupID, .data$Term) %>%
    dplyr::summarize(
      SiteN = dplyr::n(),
      SiteHighGrade = mean(.data$Grade >= 3),
      .groups = "drop"
    ) %>%
    dplyr::filter(.data$SiteN >= nMinTermSite) %>%
    dplyr::left_join(dfStudyTerm, by = "Term") %>%
    dplyr::mutate(
      Difference = .data$SiteHighGrade - .data$StudyHighGrade,
      ZScore = .data$Difference /
        sqrt(.data$StudyHighGrade * (1 - .data$StudyHighGrade) / .data$SiteN),
      Flagged = abs(.data$Difference) >= nDiffThreshold,
      FlaggedZ = abs(.data$ZScore) >= nZThreshold,
      Direction = dplyr::case_when(
        !.data$Flagged ~ "Consistent",
        .data$Difference > 0 ~ "Over-grading",
        TRUE ~ "Under-grading"
      )
    ) %>%
    dplyr::arrange(dplyr::desc(abs(.data$Difference)))
}

#' Summarize term-level grading inconsistency by site
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Rolls [AEGrading_TermConsistency()] up to one row per site, counting how many
#' of the evaluated preferred terms the site grades inconsistently. Sites that
#' deviate on several independent terms are the ones worth investigating: a
#' single discrepant term is easily explained by case mix or chance, a pattern
#' across terms points at how the site applies the grading criteria.
#'
#' @param dfTermConsistency `data.frame` output of [AEGrading_TermConsistency()].
#' @param nMinFlaggedTerms `numeric` number of inconsistent terms required to
#'   flag the site for investigation. Default: `2`.
#'
#' @return `data.frame` with one row per site.
#'
#' @export
AEGrading_SiteTermSummary <- function(
  dfTermConsistency,
  nMinFlaggedTerms = 2
) {
  dfTermConsistency %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarize(
      TermsEvaluated = dplyr::n(),
      TermsFlagged = sum(.data$Flagged),
      TermsOverGraded = sum(.data$Direction == "Over-grading"),
      TermsUnderGraded = sum(.data$Direction == "Under-grading"),
      TermsFlaggedZ = sum(.data$FlaggedZ),
      MaxAbsDifference = max(abs(.data$Difference)),
      MaxAbsZScore = max(abs(.data$ZScore)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      Investigate = .data$TermsFlagged >= nMinFlaggedTerms,
      Pattern = dplyr::case_when(
        !.data$Investigate ~ "No signal",
        .data$TermsOverGraded > 0 & .data$TermsUnderGraded > 0 ~ "Mixed / inconsistent",
        .data$TermsOverGraded > 0 ~ "Consistently over-grading",
        TRUE ~ "Consistently under-grading"
      )
    ) %>%
    dplyr::arrange(
      dplyr::desc(.data$TermsFlagged),
      dplyr::desc(.data$MaxAbsDifference)
    )
}

#' Plot term-level grading deviation as a site-by-term heatmap
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Shows, for each site and each of the most common preferred terms, how far the
#' site's Grade 3+ proportion sits from the study-wide proportion for that term.
#' Cells are blank where the site did not report enough events of that term to
#' evaluate.
#'
#' @param dfTermConsistency `data.frame` output of [AEGrading_TermConsistency()].
#' @param nMinFlaggedTerms `numeric` restrict the plot to sites flagged on at
#'   least this many terms. Set to `0` to show all evaluated sites. Default: `1`.
#' @param strTitle `character` plot title.
#'
#' @return `ggplot` object.
#'
#' @export
Visualize_TermGradingHeatmap <- function(
  dfTermConsistency,
  nMinFlaggedTerms = 1,
  strTitle = "Site vs. study Grade 3+ proportion, by preferred term"
) {
  dfKeep <- dfTermConsistency %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::filter(sum(.data$Flagged) >= nMinFlaggedTerms) %>%
    dplyr::ungroup()

  dfOrder <- dfKeep %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::summarize(n = sum(.data$Flagged), .groups = "drop") %>%
    dplyr::arrange(.data$n)

  dfPlot <- dfKeep %>%
    dplyr::mutate(GroupID = factor(.data$GroupID, levels = dfOrder$GroupID))

  ggplot2::ggplot(
    dfPlot,
    ggplot2::aes(x = .data$Term, y = .data$GroupID, fill = .data$Difference)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.6) +
    ggplot2::geom_text(
      data = dfPlot %>% dplyr::filter(.data$Flagged),
      ggplot2::aes(label = sprintf("%+.0f", .data$Difference * 100)),
      size = 2.6,
      colour = "black"
    ) +
    ggplot2::scale_fill_gradient2(
      low = "#2166AC",
      mid = "#F7F7F7",
      high = "#B2182B",
      midpoint = 0,
      limits = c(-0.6, 0.6),
      oob = scales::squish,
      labels = scales::percent,
      name = "Site - study\nGrade 3+"
    ) +
    ggplot2::labs(
      title = strTitle,
      subtitle = "Blue = under-grading relative to the study, red = over-grading. Labels show the percentage-point gap on flagged pairs.",
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 40, hjust = 1, size = 8),
      axis.text.y = ggplot2::element_text(size = 7),
      panel.grid = ggplot2::element_blank(),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30")
    )
}
