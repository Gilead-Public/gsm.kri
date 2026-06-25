#' Premature-death reason counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts `deathcls` among premature deaths (`death_dy <= window`). Falls back
#' to `"Unknown"` for missing reasons or when the `deathcls` column is absent.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid`, `death_dy`, and
#'   optionally `deathcls`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#'
#' @return A `data.frame` with `death_reason` and `n` columns, sorted by `n` descending.
#' @export
pd_ReasonCounts <- function(dfDeath, nWindowDays = 90) {
  coh <- pd_PrematureCohort(dfDeath, nWindowDays = nWindowDays)
  coh$death_reason <- pd_DeathReason(coh)
  s <- pd_ReasonSlice(coh)
  tibble::tibble(death_reason = s$reason, n = s$n)
}

#' Premature-death reason slice (internal kernel)
#'
#' @description
#' Shared kernel: count -> arrange -> build hover. Returns the slice contract
#' `list(reason, n, hover)`. The premature-death percentage is over the slice
#' total. The enrolled-percentage line is conditional on `nEnrolled`.
#'
#' @param dfReason `data.frame` with a `death_reason` column.
#' @param nEnrolled `numeric` or `NULL`. When non-NULL, adds a "% of enrolled"
#'   hover line using this as the denominator.
#'
#' @return A named `list` with `reason`, `n`, and `hover` character/integer vectors.
#' @noRd
pd_ReasonSlice <- function(dfReason, nEnrolled = NULL) {
  g <- dfReason %>%
    dplyr::count(.data$death_reason, name = "n") %>%
    dplyr::arrange(dplyr::desc(.data$n))
  total <- sum(g$n)
  hover <- paste0(
    "Reason: ",
    g$death_reason,
    "<br>Subjects: ",
    g$n,
    if (!is.null(nEnrolled)) {
      paste0("<br>% of enrolled: ", pd_PctLabel(g$n, nEnrolled))
    } else {
      ""
    },
    "<br>% of premature deaths: ",
    pd_PctLabel(g$n, total)
  )
  list(reason = g$death_reason, n = g$n, hover = hover)
}

#' Premature-death reason bar chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Renders a horizontal bar chart from a reason slice produced by
#' [pd_ReasonByCountry()] or derived inside [pd_ReasonDist()]. Each bar is
#' labelled with its count (placed inside the bar, or just outside when the bar
#' is too narrow to hold the label).
#'
#' @param slice A named `list` with `reason`, `n`, and `hover` vectors, as
#'   returned by the internal kernel `pd_ReasonSlice` or elements of the list
#'   returned by [pd_ReasonByCountry()].
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_ReasonBar <- function(slice) {
  rlang::check_installed("plotly", reason = "to run `pd_ReasonBar()`")
  df <- data.frame(
    reason = slice$reason,
    n = slice$n,
    hover = slice$hover,
    stringsAsFactors = FALSE
  )
  plotly::plot_ly(
    df,
    x = ~n,
    y = ~ stats::reorder(reason, n),
    type = "bar",
    orientation = "h",
    text = ~n,
    textposition = "auto",
    customdata = ~hover,
    hovertemplate = "%{customdata}<extra></extra>"
  ) %>%
    plotly::layout(
      xaxis = list(title = "Premature Deaths"),
      yaxis = list(title = "Reason")
    )
}

#' Premature-death reason distribution chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Horizontal bar of `deathcls` counts among premature deaths. Each bar is
#' labelled with its count (placed inside the bar, or just outside when the bar
#' is too narrow to hold the label).
#'
#' @inheritParams pd_ReasonCounts
#' @param nEnrolled `numeric` Total enrolled subjects, used for the "% of enrolled"
#'   tooltip line. When `NULL` (default) that line is omitted. Default: `NULL`.
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_ReasonDist <- function(dfDeath, nWindowDays = 90, nEnrolled = NULL) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !(is.numeric(nWindowDays) &&
      length(nWindowDays) == 1 &&
      nWindowDays > 0),
    message = "nWindowDays must be a positive number"
  )
  rlang::check_installed("plotly", reason = "to run `pd_ReasonDist()`")

  coh <- pd_PrematureCohort(dfDeath, nWindowDays = nWindowDays)
  coh$death_reason <- pd_DeathReason(coh)
  pd_ReasonBar(pd_ReasonSlice(coh, nEnrolled = nEnrolled))
}

#' Premature-death reason counts by country
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reason (`deathcls`) counts among premature deaths, split per country, plus an
#' `"__ALL__"` aggregate over every premature death. Powers the country-reactive
#' Reasons chart: the report serializes this to JSON and a client handler swaps
#' the bar to the clicked country's slice. Each slice is sorted by descending
#' count and carries a prebuilt hover string, so the client needs no arithmetic.
#'
#' @inheritParams pd_ReasonCounts
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `country`,
#'   joined onto each death to attribute it to a country.
#' @param nEnrolledByCountry `named numeric` or `NULL`. When provided, each
#'   per-country slice gains a "% of enrolled" hover line using the element
#'   named by the country as its denominator. Countries absent from the lookup
#'   receive no enrolled line. Default: `NULL` (no enrolled line; backward-
#'   compatible with existing callers).
#' @param nEnrolled `numeric` or `NULL`. When provided, the `"__ALL__"` slice
#'   gains a "% of enrolled" hover line using this as the denominator.
#'   Default: `NULL`.
#'
#' @return A named `list`: one element per country (and `"__ALL__"`), each a
#'   `list` with `reason`, `n`, and `hover` vectors sorted by descending `n`.
#' @export
pd_ReasonByCountry <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  nEnrolledByCountry = NULL,
  nEnrolled = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  coh <- pd_PrematureCohort(dfDeath, dfSubjects, nWindowDays = nWindowDays)
  if (!"country" %in% names(coh)) {
    coh$country <- NA_character_
  }
  coh$death_reason <- pd_DeathReason(coh)
  coh <- dplyr::mutate(
    coh,
    country = dplyr::coalesce(as.character(.data$country), "Unknown")
  )

  groups <- split(coh, coh$country)
  out <- Map(
    function(df, ctry) {
      pd_ReasonSlice(df, nEnrolled = nEnrolledByCountry[[ctry]])
    },
    groups,
    names(groups)
  )
  out[["__ALL__"]] <- pd_ReasonSlice(coh, nEnrolled = nEnrolled)
  out
}
