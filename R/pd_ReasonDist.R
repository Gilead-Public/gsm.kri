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
  if (!"deathcls" %in% names(dfDeath)) {
    dfDeath$deathcls <- NA_character_
  }

  pd_PrematureCohort(dfDeath, nWindowDays = nWindowDays) %>%
    dplyr::mutate(
      death_reason = dplyr::coalesce(.data$deathcls, "Unknown")
    ) %>%
    dplyr::count(.data$death_reason, name = "n") %>%
    dplyr::arrange(dplyr::desc(.data$n))
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

  dfCounts <- pd_ReasonCounts(dfDeath, nWindowDays)
  nPremature <- sum(dfCounts$n)

  dfCounts <- dfCounts %>%
    dplyr::mutate(
      text = paste0(
        "Reason: ",
        .data$death_reason,
        "<br>Subjects: ",
        .data$n,
        if (!is.null(nEnrolled)) {
          paste0("<br>% of enrolled: ", pd_PctLabel(.data$n, nEnrolled))
        } else {
          ""
        },
        "<br>% of premature deaths: ",
        pd_PctLabel(.data$n, nPremature)
      )
    )

  plotly::plot_ly(
    dfCounts,
    x = ~n,
    y = ~ stats::reorder(death_reason, n),
    type = "bar",
    orientation = "h",
    text = ~n,
    textposition = "auto",
    customdata = ~text,
    hovertemplate = "%{customdata}<extra></extra>"
  ) %>%
    plotly::layout(
      xaxis = list(title = "Premature Deaths"),
      yaxis = list(title = "Reason")
    )
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
#'
#' @return A named `list`: one element per country (and `"__ALL__"`), each a
#'   `list` with `reason`, `n`, and `hover` vectors sorted by descending `n`.
#' @export
pd_ReasonByCountry <- function(dfDeath, dfSubjects, nWindowDays = 90) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  coh <- pd_PrematureCohort(dfDeath, dfSubjects, nWindowDays = nWindowDays)
  if (!"deathcls" %in% names(coh)) {
    coh$deathcls <- NA_character_
  }
  if (!"country" %in% names(coh)) {
    coh$country <- NA_character_
  }
  coh <- dplyr::mutate(
    coh,
    death_reason = dplyr::coalesce(.data$deathcls, "Unknown"),
    country = dplyr::coalesce(as.character(.data$country), "Unknown")
  )

  slice_for <- function(df) {
    g <- df %>%
      dplyr::count(.data$death_reason, name = "n") %>%
      dplyr::arrange(dplyr::desc(.data$n))
    total <- sum(g$n)
    list(
      reason = g$death_reason,
      n = g$n,
      hover = paste0(
        "Reason: ",
        g$death_reason,
        "<br>Subjects: ",
        g$n,
        "<br>% of premature deaths: ",
        pd_PctLabel(g$n, total)
      )
    )
  }

  out <- lapply(split(coh, coh$country), slice_for)
  out[["__ALL__"]] <- slice_for(coh)
  out
}
