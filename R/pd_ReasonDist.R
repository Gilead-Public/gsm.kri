#' Premature-death reason counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Counts `death_reason` among premature deaths (`death_dy <= window`). Falls back
#' to `"Unknown"` for missing reasons or when the `death_reason` column is absent.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid`, `death_dy`, and
#'   optionally `death_reason`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#'
#' @return A `data.frame` with `death_reason` and `n` columns, sorted by `n` descending.
#' @export
pd_ReasonCounts <- function(dfDeath, nWindowDays = 90) {
  if (!"death_reason" %in% names(dfDeath)) {
    dfDeath$death_reason <- NA_character_
  }

  dfDeath %>%
    dplyr::filter(!is.na(.data$death_dy) & .data$death_dy <= nWindowDays) %>%
    dplyr::mutate(
      death_reason = dplyr::coalesce(.data$death_reason, "Unknown")
    ) %>%
    dplyr::count(.data$death_reason, name = "n") %>%
    dplyr::arrange(dplyr::desc(.data$n))
}

#' Premature-death reason distribution chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Horizontal bar of `death_reason` counts among premature deaths.
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
        "Reason: ", .data$death_reason,
        "<br>Subjects: ", .data$n,
        if (!is.null(nEnrolled)) {
          paste0("<br>% of enrolled: ", pd_PctLabel(.data$n, nEnrolled))
        } else {
          ""
        },
        "<br>% of premature deaths: ", pd_PctLabel(.data$n, nPremature)
      )
    )

  plotly::plot_ly(
    dfCounts,
    x = ~n,
    y = ~ stats::reorder(death_reason, n),
    type = "bar",
    orientation = "h",
    text = ~text,
    hovertemplate = "%{text}<extra></extra>"
  ) %>%
    plotly::layout(
      xaxis = list(title = "Premature Deaths"),
      yaxis = list(title = "Reason")
    )
}
