#' Randomization-to-death scatter
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Scatter of premature deaths: x = days from randomization to death (`death_dy`),
#' y = group, colour = `treatment_related`. Subjects who died after the window are
#' excluded. Degrades to a single uncoloured series when `treatment_related` is
#' absent (e.g. before the gsm.mapping `complete_death()` extension lands).
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid`, `death_dy`, and
#'   optionally `treatment_related`.
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `strGroupCol`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#' @param strGroupCol `character` Column in `dfSubjects` to group by. Default: "invid".
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_RandToDeathScatter <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "invid",
  strGroupLabel = "Group"
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

  if (!"treatment_related" %in% names(dfDeath)) {
    dfDeath$treatment_related <- NA
  }

  dfPlot <- dfDeath %>%
    dplyr::filter(!is.na(.data$death_dy) & .data$death_dy <= nWindowDays) %>%
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
