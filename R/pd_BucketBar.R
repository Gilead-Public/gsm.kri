#' Premature-death bucket labels
#'
#' @description
#' The three bucket labels (`<=30d`, `31-Wd`, `Alive at Wd`, where `W` is
#' `nWindowDays`), in RAG order. Shared by the bucket bar and the
#' randomization-to-death scatter so labels and colors stay in lockstep.
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-3 `character` vector of bucket labels.
#' @noRd
pd_BucketLabels <- function(nWindowDays) {
  c(
    "<=30d",
    paste0("31-", nWindowDays, "d"),
    paste0("Alive at ", nWindowDays, "d")
  )
}

#' Premature-death bucket RAG colors
#'
#' @description
#' Named (red / amber / green) color vector keyed by [pd_BucketLabels()].
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-3 named `character` vector of hex colors.
#' @noRd
pd_RagColors <- function(nWindowDays) {
  rag_colors <- c(
    colorScheme("red", "dark"),
    colorScheme("amber", "dark"),
    colorScheme("green", "dark")
  )
  names(rag_colors) <- pd_BucketLabels(nWindowDays)
  rag_colors
}

#' Premature-death bucket counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Categorizes every enrolled subject into a premature-death bucket
#' (`<=30d`, `31-Wd`, or `Alive at Wd`, where `W` is `nWindowDays`) grouped by `strGroupCol`.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid` and `death_dy`.
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `strGroupCol`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#' @param strGroupCol `character` Column in `dfSubjects` to group by. Default: "studyid".
#' @param strOuterCol `character` Optional parent column in `dfSubjects` for a
#'   two-tier (multicategory) axis (e.g. "country" to bracket sites by country).
#'   When `NULL` (default) the result is the flat one-tier count.
#'
#' @return A `data.frame` with `GroupID`, `Bucket`, and `n` columns. When
#'   `strOuterCol` is set, an additional `Outer` column carries the parent tier.
#' @export
pd_BucketCounts <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strOuterCol = NULL
) {
  bucket_levels <- pd_BucketLabels(nWindowDays)

  death_dy <- dfDeath$death_dy[match(dfSubjects$subjid, dfDeath$subjid)]
  premature <- !is.na(death_dy) & death_dy <= nWindowDays

  bucket <- dplyr::case_when(
    premature & death_dy <= 30 ~ bucket_levels[1],
    premature ~ bucket_levels[2],
    TRUE ~ bucket_levels[3]
  )

  df <- tibble::tibble(
    GroupID = dfSubjects[[strGroupCol]],
    Bucket = factor(bucket, levels = bucket_levels)
  )

  if (is.null(strOuterCol)) {
    return(
      dplyr::count(df, .data$GroupID, .data$Bucket, name = "n", .drop = FALSE)
    )
  }

  # Multicategory: carry the parent tier (country for sites, study for
  # countries), labelling a missing parent "Unknown", and sort so each parent is
  # one contiguous run -- interleaved rows make Plotly draw a fragmented bracket.
  outer <- dfSubjects[[strOuterCol]]
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
#' Stacked bar of premature-death bucket counts per group.
#'
#' @inheritParams pd_BucketCounts
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#' @param strOuterCol `character` Optional parent column for a two-tier
#'   (multicategory) x-axis bracketing each group under its parent (e.g.
#'   "country" for sites). `NULL` (default) renders the flat one-tier bar.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_BucketBar <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
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
  rlang::check_installed("plotly", reason = "to run `pd_BucketBar()`")

  dfCounts <- pd_BucketCounts(
    dfDeath,
    dfSubjects,
    nWindowDays,
    strGroupCol,
    strOuterCol
  )

  rag_colors <- pd_RagColors(nWindowDays)

  dfCounts <- dfCounts %>%
    dplyr::group_by(.data$GroupID) %>%
    dplyr::mutate(GroupTotal = sum(.data$n)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      text = paste0(
        "Bucket: ",
        .data$Bucket,
        "<br>Subjects: ",
        .data$n,
        " (",
        pd_PctLabel(.data$n, .data$GroupTotal),
        ")"
      ),
      label = dplyr::if_else(
        .data$n == 0,
        "",
        paste0(
          .data$Bucket,
          ": ",
          .data$n,
          " (",
          pd_PctLabel(.data$n, .data$GroupTotal),
          ")"
        )
      )
    )

  # Plotly has no native "hide label if it doesn't fit", so after each draw we
  # hide any on-bar label whose box overflows its own bar's box. Bound to
  # plotly_afterplot so it re-applies on resize/redraw, not just initial render.
  js_hide_overflow <- r"(function(el, x) {
  function hideOverflow() {
    el.querySelectorAll('text.bartext-inside').forEach(function(t) {
      t.style.display = '';
      var pt = t.closest('g.point'); if (!pt) return;
      var bar = pt.querySelector('path'); if (!bar) return;
      var tb = t.getBBox(), bb = bar.getBBox();
      if (bb.width === 0 && bb.height === 0) return;
      // -2/-1: the bar stroke straddles the edge, so allow ~1px on each side
      if (tb.width > bb.width - 2 || tb.height > bb.height - 1) t.style.display = 'none';
    });
  }
  requestAnimationFrame(hideOverflow);
  el.on('plotly_afterplot', hideOverflow);
})"

  # Flat one-tier axis: the original single-trace bar (Plotly's color= split is
  # fine for a plain string x). Preserved verbatim for the Study chart.
  if (is.null(strOuterCol)) {
    return(
      htmlwidgets::onRender(
        plotly::plot_ly(
          dfCounts,
          x = ~GroupID,
          y = ~n,
          color = ~Bucket,
          colors = rag_colors,
          type = "bar",
          text = ~label,
          textposition = "inside",
          insidetextanchor = "middle",
          constraintext = "none",
          textangle = 0,
          # color = ~Bucket tints the label text with the bucket color too; set it
          # white explicitly so labels are readable on the dark RAG fills. The
          # two-tier path has no color= aesthetic and keeps Plotly's auto-contrast.
          insidetextfont = list(color = "white"),
          customdata = ~text,
          hovertemplate = "%{customdata}<extra></extra>"
        ) %>%
          plotly::layout(
            barmode = "stack",
            xaxis = list(title = strGroupLabel),
            yaxis = list(title = "Subjects"),
            legend = list(title = list(text = "Bucket"))
          ),
        js_hide_overflow
      )
    )
  }

  # Two-tier (multicategory) axis. Plotly's high-level color= split positionally
  # mis-subsets a list-valued x, so build one trace per bucket with its own
  # aligned [outer, inner] x. Looping in bucket-label order keeps colour and
  # stack order identical to the flat chart.
  p <- plotly::plot_ly()
  for (bk in pd_BucketLabels(nWindowDays)) {
    d <- dplyr::filter(dfCounts, .data$Bucket == bk)
    p <- plotly::add_bars(
      p,
      # I() keeps each tier an array under plotly's auto_unbox JSON: a bucket with
      # a single group would otherwise serialize list(Outer, Inner) as a flat
      # [outer, inner], collapsing the 2-D axis in the browser.
      x = list(I(d$Outer), I(d$GroupID)),
      y = d$n,
      name = bk,
      marker = list(color = unname(rag_colors[bk])),
      text = d$label,
      customdata = d$text,
      hovertemplate = "%{customdata}<extra></extra>"
    )
  }
  # style() keeps textposition/constraintext as a scalar per-trace (add_bars()
  # would broadcast them to per-row vectors, causing isTRUE(... == "inside")
  # to fail).
  p <- plotly::style(
    p,
    textposition = "inside",
    insidetextanchor = "middle",
    constraintext = "none",
    textangle = 0
  )
  htmlwidgets::onRender(
    plotly::layout(
      p,
      barmode = "stack",
      xaxis = list(title = strGroupLabel),
      yaxis = list(title = "Subjects"),
      legend = list(title = list(text = "Bucket"))
    ),
    js_hide_overflow
  )
}
