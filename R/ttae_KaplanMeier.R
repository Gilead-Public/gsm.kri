#' Kaplan-Meier estimate for a time-to-event analysis input
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Product-limit (Kaplan-Meier) estimate of the event-free probability over
#' time, computed from the subject-level frame produced by
#' [Input_TimeToEvent()]. Used by [Report_TimeToAE()] to show the shape of the
#' time-to-first-AE distribution, which a single site-level rate cannot convey.
#'
#' @details
#' Implemented directly rather than via `survival::survfit()` to avoid adding a
#' dependency for one curve. Subjects censored at the same time as an event are
#' treated as still at risk at that time, the standard convention.
#'
#' @param dfInput `data.frame` Subject-level frame with `Numerator` (0/1 event
#'   indicator) and `Denominator` (time at risk), as returned by
#'   [Input_TimeToEvent()].
#'
#' @return `data.frame` with one row per distinct event time, plus a leading row
#'   at time 0. Columns: `Time`, `NRisk`, `NEvent`, `NCensored`, and `Survival`
#'   (event-free probability).
#'
#' @examples
#' dfInput <- data.frame(
#'   Numerator = c(1, 1, 0, 1, 0),
#'   Denominator = c(5, 10, 12, 20, 30)
#' )
#' ttae_KaplanMeier(dfInput)
#'
#' @keywords KRI
#' @export
ttae_KaplanMeier <- function(dfInput) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfInput),
    message = "dfInput is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !all(c("Numerator", "Denominator") %in% names(dfInput)),
    message = "dfInput must contain Numerator and Denominator columns"
  )

  dfClean <- dfInput %>%
    dplyr::filter(
      !is.na(.data$Denominator),
      !is.na(.data$Numerator),
      .data$Denominator >= 0
    )

  dfEmpty <- data.frame(
    Time = 0,
    NRisk = nrow(dfClean),
    NEvent = 0,
    NCensored = 0,
    Survival = 1
  )

  if (nrow(dfClean) == 0) {
    return(dfEmpty)
  }

  # Carry the curve flat out to the last day of follow-up. Without this a cohort
  # with no events is a single point and plots as nothing at all, hiding exactly
  # the groups a long-time-to-event flag is meant to surface.
  nLastFollowUp <- max(dfClean$Denominator)

  if (sum(dfClean$Numerator > 0) == 0) {
    return(dplyr::bind_rows(
      dfEmpty,
      data.frame(
        Time = nLastFollowUp,
        NRisk = 0,
        NEvent = 0,
        NCensored = sum(dfClean$Denominator == nLastFollowUp),
        Survival = 1
      )
    ))
  }

  vEventTimes <- sort(unique(dfClean$Denominator[dfClean$Numerator > 0]))

  dfCurve <- purrr::map(vEventTimes, function(t) {
    data.frame(
      Time = t,
      NRisk = sum(dfClean$Denominator >= t),
      NEvent = sum(dfClean$Denominator == t & dfClean$Numerator > 0),
      NCensored = sum(dfClean$Denominator == t & dfClean$Numerator == 0)
    )
  }) %>%
    purrr::list_rbind() %>%
    dplyr::mutate(Survival = cumprod(1 - .data$NEvent / .data$NRisk))

  dfOut <- dplyr::bind_rows(dfEmpty, dfCurve)

  if (nLastFollowUp > max(dfCurve$Time)) {
    dfOut <- dplyr::bind_rows(
      dfOut,
      data.frame(
        Time = nLastFollowUp,
        NRisk = 0,
        NEvent = 0,
        NCensored = sum(dfClean$Denominator == nLastFollowUp),
        Survival = dfCurve$Survival[nrow(dfCurve)]
      )
    )
  }

  dfOut
}

#' Median event-free time from a Kaplan-Meier curve
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' First time at which the Kaplan-Meier event-free probability drops to 0.5 or
#' below. Returns `NA` when fewer than half of the subjects experience the event,
#' which is the honest answer rather than the largest observed time.
#'
#' @param dfCurve `data.frame` Output of [ttae_KaplanMeier()].
#'
#' @return `numeric` Median event-free time, or `NA_real_` if not reached.
#'
#' @examples
#' dfInput <- data.frame(
#'   Numerator = c(1, 1, 0, 1, 0),
#'   Denominator = c(5, 10, 12, 20, 30)
#' )
#' ttae_MedianTime(ttae_KaplanMeier(dfInput))
#'
#' @keywords KRI
#' @export
ttae_MedianTime <- function(dfCurve) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfCurve) || !"Survival" %in% names(dfCurve),
    message = "dfCurve must be a data.frame with a Survival column"
  )
  vBelow <- which(dfCurve$Survival <= 0.5)
  if (length(vBelow) == 0) {
    return(NA_real_)
  }
  dfCurve$Time[min(vBelow)]
}
