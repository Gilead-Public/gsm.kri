#' Premature-death category counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts the [pd_Classify()] category of each enrolled subject per
#' `strGroupCol`. `.drop = FALSE` keeps every category present for every group so
#' the stacked bar and its colors stay aligned.
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#' @param strGroupCol `character` Column to group by. Default "studyid".
#' @param strOuterCol `character` Optional parent column for a two-tier
#'   (multicategory) axis. `NULL` (default) is the flat one-tier count.
#'
#' @return A `data.frame` with `GroupID`, `Bucket`, `n` (and `Outer` when
#'   `strOuterCol` is set).
#' @export
pd_BucketCounts <- function(
  dfClassified,
  strGroupCol = "studyid",
  strOuterCol = NULL
) {
  df <- tibble::tibble(
    GroupID = dfClassified[[strGroupCol]],
    Bucket = dfClassified$Category
  )

  if (is.null(strOuterCol)) {
    return(
      dplyr::count(df, .data$GroupID, .data$Bucket, name = "n", .drop = FALSE)
    )
  }

  outer <- dfClassified[[strOuterCol]]
  df$Outer <- dplyr::if_else(is.na(outer), "Unknown", as.character(outer))

  df %>%
    dplyr::count(
      .data$Outer,
      .data$GroupID,
      .data$Bucket,
      name = "n",
      .drop = FALSE
    ) %>%
    dplyr::arrange(.data$Outer, .data$GroupID)
}

#' Premature-death bucket bar chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Stacked bar of [pd_Classify()] category counts per group. Each point's
#' `customdata` carries `[count, pct]` so the report can toggle counts/percent
#' client-side. On-bar `text` shows the bare count (blank for empty buckets).
#' Each of the five categories is its own legend entry; traces stack bottom-to-top
#' in `pd_DisplayOrder()` order (best outcome at the base, death-within-30 on top).
#'
#' @param dfClassified `data.frame` Output of [pd_Classify()].
#' @param nWindowDays `numeric` Window in days (legend/color vocabulary). Default 90.
#' @param strGroupCol `character` Column to group by. Default "studyid".
#' @param strGroupLabel `character` Axis label. Default "Group".
#' @param strOuterCol `character` Optional parent column for a two-tier x-axis.
#' @param strOuterLabel `character` Optional tooltip label for the parent tier.
#' @param bRangeSlider `logical` Add a scroll-only x range slider. Default FALSE.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_BucketBar <- function(
  dfClassified,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
  strOuterCol = NULL,
  strOuterLabel = NULL,
  bRangeSlider = FALSE
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfClassified),
    message = "dfClassified is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.logical(bRangeSlider),
    message = "bRangeSlider must be logical"
  )
  rlang::check_installed("plotly", reason = "to run `pd_BucketBar()`")

  dfCounts <- pd_BucketCounts(dfClassified, strGroupCol, strOuterCol)
  cat_colors <- pd_CategoryColors(nWindowDays)

  dfCounts <- dfCounts %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::mutate(GroupTotal = sum(.data$n)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      Pct = dplyr::if_else(
        .data$GroupTotal > 0,
        100 * .data$n / .data$GroupTotal,
        0
      ),
      # FIX-2: bare count on the bar (blank for an empty bucket).
      label = dplyr::if_else(.data$n == 0, "", as.character(.data$n))
    )

  js_hide_overflow <- r"(function(el, x) {
  function hideOverflow() {
    el.querySelectorAll('.cartesianlayer text.bartext-inside')
      .forEach(function(t) {
      t.style.display = '';
      var pt = t.closest('g.point'); if (!pt) return;
      var bar = pt.querySelector('path'); if (!bar) return;
      var tb = t.getBBox(), bb = bar.getBBox();
      if (bb.width === 0 && bb.height === 0) return;
      if (tb.width > bb.width - 2 || tb.height > bb.height - 1) t.style.display = 'none';
    });
  }
  requestAnimationFrame(hideOverflow);
  el.on('plotly_afterplot', hideOverflow);
})"

  strIdentity <- ""
  if (!is.null(strOuterCol)) {
    if (!is.null(strOuterLabel)) {
      strIdentity <- paste0("<br>", strOuterLabel, ": %{customdata[3]}")
    }
    strIdentity <- paste0(
      strIdentity,
      "<br>",
      strGroupLabel,
      ": %{customdata[2]}"
    )
  }

  p <- plotly::plot_ly()
  for (ct in pd_DisplayOrder(nWindowDays)) {
    d <- dplyr::filter(dfCounts, .data$Bucket == ct)
    meta <- pd_LegendMeta(ct, nWindowDays)
    x <- if (is.null(strOuterCol)) {
      d$GroupID
    } else {
      list(I(d$Outer), I(d$GroupID))
    }
    p <- plotly::add_bars(
      p,
      x = x,
      y = d$n,
      name = meta$name,
      legendgroup = meta$group,
      legendgrouptitle = if (is.null(meta$grouptitle)) {
        NULL
      } else {
        list(text = meta$grouptitle)
      },
      marker = list(color = unname(cat_colors[ct])),
      text = d$label,
      customdata = if (is.null(strOuterCol)) {
        I(Map(function(cnt, pct) list(cnt, pct), d$n, d$Pct))
      } else {
        I(Map(
          function(cnt, pct, grp, out) list(cnt, pct, grp, out),
          d$n,
          d$Pct,
          d$GroupID,
          d$Outer
        ))
      },
      hovertemplate = paste0(
        "Category: ",
        ct,
        strIdentity,
        "<br>Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)<extra></extra>"
      )
    )
  }

  p <- plotly::style(
    p,
    textposition = "inside",
    insidetextanchor = "middle",
    constraintext = "none",
    textangle = 0,
    insidetextfont = list(color = "white")
  )

  xaxis <- list(title = strGroupLabel)
  if (bRangeSlider) {
    xaxis$rangeslider <- list(
      visible = TRUE,
      thickness = 0.04,
      bgcolor = "#f2f2f2",
      bordercolor = colorScheme("gray", "dark"),
      borderwidth = 1
    )
  }

  htmlwidgets::onRender(
    plotly::layout(
      p,
      barmode = "stack",
      xaxis = xaxis,
      yaxis = list(title = "Subjects"),
      legend = list(title = list(text = "Category"))
    ),
    js_hide_overflow
  )
}
