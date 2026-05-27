#' Randomization-to-death scatter
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Scatter of premature deaths: x = days from randomization to death (`death_dy`).
#' Subjects who died after the window are excluded.
#'
#' By default y = group and colour = `treatment_related` (degrading to a single
#' uncoloured series when `treatment_related` is absent, e.g. before the
#' gsm.mapping `complete_death()` extension lands). When `dSnapshotDate` is
#' supplied the y-axis instead becomes numeric — days from randomization to the
#' snapshot date (`SnapshotDate - death_dt + death_dy`) — and points are coloured
#' by premature-death bucket (`<=30d` / `31-Wd`), reusing the RAG colours of
#' [pd_BucketBar()]. This is the study-level view, where the categorical group
#' axis would otherwise collapse to a single row.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid`, `death_dy`, and
#'   optionally `treatment_related`. When `dSnapshotDate` is supplied, `death_dt`
#'   is also required.
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `strGroupCol`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#' @param strGroupCol `character` Column in `dfSubjects` to group by. Default: "invid".
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#' @param dSnapshotDate `Date` (or coercible) Snapshot date. When non-`NULL`,
#'   switches the y-axis to numeric days-from-randomization-to-snapshot and colours
#'   by bucket. Default: `NULL` (categorical group y-axis).
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_RandToDeathScatter <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group",
  dSnapshotDate = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfSubjects),
    message = "dfSubjects is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !(is.numeric(nWindowDays) &&
      length(nWindowDays) == 1 &&
      nWindowDays > 0),
    message = "nWindowDays must be a positive number"
  )
  rlang::check_installed("plotly", reason = "to run `pd_RandToDeathScatter()`")

  dfPlot <- dfDeath %>%
    dplyr::filter(!is.na(.data$death_dy) & .data$death_dy <= nWindowDays)

  if (!is.null(dSnapshotDate)) {
    gsm.core::stop_if(
      cnd = !("death_dt" %in% names(dfDeath)),
      message = "dfDeath must contain death_dt when dSnapshotDate is supplied"
    )

    bucket_labels <- pd_BucketLabels(nWindowDays)
    rag_colors <- pd_RagColors(nWindowDays)

    dfPlot <- dfPlot %>%
      dplyr::mutate(
        RandToSnapshot = as.numeric(
          as.Date(dSnapshotDate) - as.Date(.data$death_dt)
        ) +
          .data$death_dy,
        Bucket = factor(
          dplyr::if_else(
            .data$death_dy <= 30,
            bucket_labels[1],
            bucket_labels[2]
          ),
          levels = bucket_labels[1:2]
        )
      )

    return(
      plotly::plot_ly(
        dfPlot,
        x = ~death_dy,
        y = ~RandToSnapshot,
        color = ~Bucket,
        colors = rag_colors[1:2],
        type = "scatter",
        mode = "markers"
      ) %>%
        plotly::layout(
          xaxis = list(title = "Days from Randomization to Death"),
          yaxis = list(
            title = "Days from Randomization to Snapshot",
            rangemode = "tozero"
          ),
          legend = list(title = list(text = "Bucket"))
        )
    )
  }

  if (!"treatment_related" %in% names(dfDeath)) {
    dfPlot$treatment_related <- NA
  }

  dfPlot <- dfPlot %>%
    dplyr::left_join(
      dfSubjects %>%
        dplyr::select("subjid", Group = dplyr::all_of(strGroupCol)),
      by = "subjid"
    )

  plotly::plot_ly(
    dfPlot,
    x = ~death_dy,
    y = ~Group,
    color = ~treatment_related,
    type = "scatter",
    mode = "markers"
  ) %>%
    plotly::layout(
      xaxis = list(title = "Days from Randomization to Death"),
      yaxis = list(title = strGroupLabel),
      legend = list(title = list(text = "Treatment Related"))
    )
}
