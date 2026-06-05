#' Randomization-to-death scatter
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Scatter of premature deaths: x = days from randomization to death (`death_dy`),
#' colored by premature-death bucket (`<=30d` / `31-Wd`) using the RAG colors of
#' [pd_BucketBar()]. By default y = group (categorical). When `dSnapshotDate` is
#' supplied the y-axis instead becomes numeric — days from randomization to the
#' snapshot (`SnapshotDate − death_dt + death_dy`), the full window the subject
#' would have been observed had they lived — for the study-level view, where the
#' categorical group axis would otherwise collapse to one row. Country, site,
#' subject, days to death, bucket, and treatment-related status are surfaced in
#' the hover tooltip.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid`, `death_dy`, and
#'   optionally `treatment_related` (shown as "Unknown" when absent). When
#'   `dSnapshotDate` is supplied, `death_dt` is also required.
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `strGroupCol`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#' @param strGroupCol `character` Column in `dfSubjects` to group by. Default: "invid".
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#' @param dSnapshotDate `Date` (or coercible) When non-`NULL`, selects the
#'   study-level view: y becomes days from randomization to the snapshot. Default:
#'   `NULL` (categorical group y-axis).
#' @param strOuterCol `character` Optional parent column for a two-tier
#'   (multicategory) y-axis bracketing each group under its parent (e.g.
#'   "country" for sites). Ignored in the study view (numeric y). Default `NULL`.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_RandToDeathScatter <- function(
  dfDeath,
  dfSubjects,

  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group",
  dSnapshotDate = NULL,
  strOuterCol = NULL
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

  is_study <- !is.null(dSnapshotDate)
  if (is_study) {
    gsm.core::stop_if(
      cnd = !("death_dt" %in% names(dfDeath)),
      message = "dfDeath must contain death_dt when dSnapshotDate is supplied"
    )
  }

  bucket_labels <- pd_BucketLabels(nWindowDays)
  rag_colors <- pd_RagColors(nWindowDays)

  if (!"treatment_related" %in% names(dfDeath)) {
    dfDeath$treatment_related <- NA
  }

  dfPlot <- pd_PrematureCohort(dfDeath, dfSubjects, nWindowDays) %>%
    dplyr::mutate(Group = .data[[strGroupCol]])

  for (col in c("country", "invid")) {
    if (!col %in% names(dfPlot)) {
      dfPlot[[col]] <- NA
    }
  }

  dfPlot <- dfPlot %>%
    dplyr::mutate(
      Bucket = factor(
        dplyr::if_else(
          .data$death_dy <= 30,
          bucket_labels[1],
          bucket_labels[2]
        ),
        levels = bucket_labels[1:2]
      ),
      text = paste0(
        "Country: ",
        .data$country,
        "<br>Site: ",
        .data$invid,
        "<br>Subject: ",
        .data$subjid,
        "<br>Days to death: ",
        .data$death_dy,
        "<br>Bucket: ",
        .data$Bucket,
        "<br>Treatment related: ",
        pd_YesNo(.data$treatment_related)
      )
    )

  if (is_study) {
    dfPlot <- dfPlot %>%
      dplyr::mutate(
        RandToSnapshot = as.numeric(
          as.Date(dSnapshotDate) - as.Date(.data$death_dt)
        ) +
          .data$death_dy
      )
  }

  # Two-tier y only in the categorical (non-study) view: the study view's y is
  # numeric days-to-snapshot and is never filtered.
  use_mc <- !is.null(strOuterCol) && !is_study
  if (use_mc) {
    outer <- dfPlot[[strOuterCol]]
    dfPlot <- dfPlot %>%
      dplyr::mutate(
        Outer = dplyr::if_else(is.na(outer), "Unknown", as.character(outer))
      ) %>%
      dplyr::arrange(.data$Outer, .data$Group)
  }

  if (use_mc) {
    # Per-bucket traces with an aligned [outer, inner] y (see pd_BucketBar for
    # why color= cannot split a list-valued axis).
    p <- plotly::plot_ly()
    for (bk in bucket_labels[1:2]) {
      d <- dplyr::filter(dfPlot, .data$Bucket == bk)
      p <- plotly::add_markers(
        p,
        x = d$death_dy,
        y = list(d$Outer, d$Group),
        name = bk,
        marker = list(color = unname(rag_colors[bk])),
        customdata = d$text,
        hovertemplate = "%{customdata}<extra></extra>"
      )
    }
  } else {
    p <- plotly::plot_ly(
      dfPlot,
      x = ~death_dy,
      y = if (is_study) ~RandToSnapshot else ~Group,
      color = ~Bucket,
      colors = rag_colors[1:2],
      type = "scatter",
      mode = "markers",
      customdata = ~text,
      hovertemplate = "%{customdata}<extra></extra>"
    )
  }

  yaxis <- if (is_study) {
    list(title = "Days from Randomization to Snapshot", rangemode = "tozero")
  } else {
    list(title = strGroupLabel)
  }

  p %>%
    plotly::layout(
      xaxis = list(title = "Days from Randomization to Death"),
      yaxis = yaxis,
      legend = list(title = list(text = "Bucket"))
    )
}
