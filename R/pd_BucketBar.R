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
#' Stacked bar of premature-death bucket counts per group. Each point's
#' `customdata` carries `[count, pct]` (pct = the bucket's share of its group's
#' enrolled subjects), so the report can toggle the y-axis between counts and
#' percentages client-side without recomputation. Two-tier (nested) charts
#' extend `customdata` to `[count, pct, group, parent]` and name the group --
#' and, when `strOuterLabel` is set, its parent -- in the hover tooltip; the flat
#' chart's single labelled axis already identifies the bar, so its tooltip stays
#' minimal. Permanent on-bar labels (`Bucket: N (P%)`, blanked for empty
#' buckets) are retained in `text`, independent of the toggle's `customdata`.
#'
#' @inheritParams pd_BucketCounts
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#' @param strOuterCol `character` Optional parent column for a two-tier
#'   (multicategory) x-axis bracketing each group under its parent (e.g.
#'   "country" for sites). `NULL` (default) renders the flat one-tier bar.
#' @param strOuterLabel `character` Optional tooltip label for the parent tier
#'   (e.g. "Country" for the site chart). When supplied, two-tier tooltips name
#'   the parent above the group. `NULL` (default) omits the parent line.
#' @param bRangeSlider `logical` When `TRUE`, adds a thin (thickness `0.04`)
#'   x-axis range slider for navigating long category axes. The report hides the
#'   slider's mini-preview via CSS, leaving a scroll-only track; see
#'   `Report_PrematureDeaths.Rmd`. Default: `FALSE`.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_BucketBar <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group",
  strOuterCol = NULL,
  strOuterLabel = NULL,
  bRangeSlider = FALSE
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
  gsm.core::stop_if(
    cnd = !is.logical(bRangeSlider),
    message = "bRangeSlider must be logical"
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

  # Per-group composition: pct = the bucket's share of its group's enrolled
  # subjects. GroupTotal is always >= 1 (every GroupID comes from a dfSubjects
  # row), so the > 0 guard is purely defensive against an impossible zero-division.
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
      # Permanent on-bar label (retained from the labels feature): blanked for
      # zero buckets. It lives in `text`, independent of the `customdata` the
      # toggle reads, so labels and the count/% toggle are orthogonal. The label's
      # % is the same per-group share as the bar, so it stays meaningful in % mode.
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
  # plotly_afterplot so it re-applies on resize/redraw -- and, crucially, after
  # each restyle/relayout the count/% toggle triggers (% mode resizes segments).
  js_hide_overflow <- r"(function(el, x) {
  function hideOverflow() {
    el.querySelectorAll('.cartesianlayer text.bartext-inside')
      .forEach(function(t) {
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

  # Tooltip identity lines, derived once (invariant across buckets). A nested
  # chart names the specific group (customdata[2]) and -- when strOuterLabel is
  # supplied -- its parent (customdata[3]); the flat chart names neither, since
  # its single labelled x-axis already identifies each bar.
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

  # One trace per bucket, in RAG label order (stack + colour order stay stable).
  # The flat (Study) and two-tier (Country/Site) charts share this loop; only the
  # x differs. The high-level color= split is avoided deliberately: it mis-subsets
  # a list-valued x and cannot carry a structured customdata (it errors on a
  # multi-column one and flattens a single-point one).
  p <- plotly::plot_ly()
  for (bk in pd_BucketLabels(nWindowDays)) {
    d <- dplyr::filter(dfCounts, .data$Bucket == bk)
    x <- if (is.null(strOuterCol)) {
      d$GroupID
    } else {
      # I() keeps each tier an array under plotly's JSON auto-unbox; a single-group
      # bucket would otherwise collapse list(Outer, Inner) to a flat [outer, inner].
      list(I(d$Outer), I(d$GroupID))
    }
    p <- plotly::add_bars(
      p,
      x = x,
      y = d$n,
      name = bk,
      marker = list(color = unname(rag_colors[bk])),
      text = d$label,
      # I(Map(...)) keeps customdata a per-point [[...], ...] array under auto-unbox
      # (a single-point trace would otherwise serialize as a flat array and read back
      # as multiple points). The report toggle reads customdata[0]/[1]; the existing
      # filter JS reindexes customdata for free.
      customdata = if (is.null(strOuterCol)) {
        # [count, pct] -- a flat chart needs no identity in customdata.
        I(Map(function(cnt, pct) list(cnt, pct), d$n, d$Pct))
      } else {
        # [count, pct, group, parent] -- the trailing two feed the tooltip's
        # group/parent lines; the toggle still only reads customdata[0]/[1].
        I(Map(
          function(cnt, pct, grp, out) list(cnt, pct, grp, out),
          d$n,
          d$Pct,
          d$GroupID,
          d$Outer
        ))
      },
      hovertemplate = paste0(
        "Bucket: ",
        bk,
        strIdentity,
        "<br>Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)<extra></extra>"
      )
    )
  }

  # style() keeps textposition/constraintext/textangle/insidetextfont as per-trace
  # scalars (add_bars would broadcast them to per-row vectors, breaking
  # isTRUE(... == "inside") in the label tests). insidetextfont = white keeps the
  # on-bar labels readable on the dark RAG fills -- the flat path previously set
  # this only because of its color= aesthetic; the unified manual path now sets it
  # explicitly for both the flat and two-tier charts.
  p <- plotly::style(
    p,
    textposition = "inside",
    insidetextanchor = "middle",
    constraintext = "none",
    textangle = 0,
    insidetextfont = list(color = "white")
  )

  # onRender re-attaches the overflow-hiding hook (retained from the labels
  # feature) so labels that no longer fit -- including after a % toggle resizes
  # the segments -- are hidden on every plotly_afterplot.
  xaxis <- list(title = strGroupLabel)
  if (bRangeSlider) {
    # Scroll-only range slider for the long Site axis: thickness 0.04 keeps the
    # track slim but still grabbable; the report hides its mini-preview via CSS
    # (#pd-*-buckets .rangeslider-rangeplot { display:none }).
    xaxis$rangeslider <- list(visible = TRUE, thickness = 0.04)
  }

  htmlwidgets::onRender(
    plotly::layout(
      p,
      barmode = "stack",
      xaxis = xaxis,
      yaxis = list(title = "Subjects"),
      legend = list(title = list(text = "Bucket"))
    ),
    js_hide_overflow
  )
}
