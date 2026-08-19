#' Derive time-to-first-event analysis input
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Builds a standard `Analysis_Input` data frame for a time-to-first-event metric.
#' Each subject contributes one row: `Numerator` is a 0/1 indicator of whether the
#' event was observed, and `Denominator` is the number of days the subject was at
#' risk (days to the first event, or days of follow-up if the event never
#' occurred). The result is shaped for [gsm.core::Transform_Rate()] followed by
#' [gsm.core::Analyze_Poisson()], which compares each group's observed event count
#' against what the study-wide fit predicts for its accumulated exposure.
#'
#' @details
#' Subjects with no qualifying event are **right-censored** at `strCensorCol`
#' rather than dropped. This matters: summarizing days-to-event over only the
#' subjects who had an event biases groups with short follow-up toward looking
#' like they have long event-free times.
#'
#' Events dated before the reference date are dropped by default
#' (`bIncludePreReferenceEvents = FALSE`), which is the usual
#' treatment-emergent definition — an AE recorded before enrollment is not a
#' post-enrollment event. Set `bIncludePreReferenceEvents = TRUE` to clamp such
#' events to day 0 instead.
#'
#' A subject whose event falls on the reference date contributes
#' `Denominator = 0`. Those subjects still contribute to the group numerator, so
#' the exposure they add is zero rather than negative. A group where *every*
#' subject has zero days at risk is dropped downstream by
#' [gsm.core::Transform_Rate()].
#'
#' @param dfSubjects `data.frame` One row per subject, containing
#'   `strSubjectCol`, `strGroupCol`, `strReferenceDateCol`, and `strCensorCol`.
#' @param dfEvents `data.frame` One row per event, containing `strSubjectCol`
#'   and `strEventDateCol`. Multiple events per subject are reduced to the
#'   earliest qualifying one.
#' @param strSubjectCol `string` Subject ID column, present in both inputs.
#'   Default: `"subjid"`.
#' @param strGroupCol `string` Grouping column in `dfSubjects`. Default: `"invid"`.
#' @param strGroupLevel `string` Value written to `GroupLevel`. Default:
#'   `strGroupCol`.
#' @param strEventDateCol `string` Event date column in `dfEvents`. Default:
#'   `"aest_dt"`.
#' @param strReferenceDateCol `string` Time-zero date column in `dfSubjects`.
#'   Default: `"firstparticipantdate"`.
#' @param strCensorCol `string` Numeric follow-up duration (days) in
#'   `dfSubjects`, used to censor subjects with no event. Default:
#'   `"timeonstudy"`.
#' @param bIncludePreReferenceEvents `logical` Keep events dated before the
#'   reference date, clamped to day 0? Default: `FALSE`.
#'
#' @return `data.frame` with columns `SubjectID`, `GroupID`, `GroupLevel`,
#'   `Numerator` (0/1 event indicator), `Denominator` (days at risk), and
#'   `Metric`.
#'
#' @examples
#' dfSubjects <- data.frame(
#'   subjid = c("S1", "S2", "S3"),
#'   invid = c("Site A", "Site A", "Site B"),
#'   firstparticipantdate = as.Date(c("2024-01-01", "2024-01-01", "2024-01-01")),
#'   timeonstudy = c(100, 100, 100)
#' )
#' dfEvents <- data.frame(
#'   subjid = c("S1", "S1", "S3"),
#'   aest_dt = as.Date(c("2024-01-11", "2024-02-01", "2023-12-01"))
#' )
#' Input_TimeToEvent(dfSubjects, dfEvents)
#'
#' @keywords KRI
#' @export
Input_TimeToEvent <- function(
  dfSubjects,
  dfEvents,
  strSubjectCol = "subjid",
  strGroupCol = "invid",
  strGroupLevel = NULL,
  strEventDateCol = "aest_dt",
  strReferenceDateCol = "firstparticipantdate",
  strCensorCol = "timeonstudy",
  bIncludePreReferenceEvents = FALSE
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfSubjects),
    message = "dfSubjects is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfEvents),
    message = "dfEvents is not a data.frame"
  )

  vSubjectCols <- c(
    strSubjectCol,
    strGroupCol,
    strReferenceDateCol,
    strCensorCol
  )
  gsm.core::stop_if(
    cnd = !all(vSubjectCols %in% names(dfSubjects)),
    message = paste0(
      "Columns not found in dfSubjects: ",
      paste(setdiff(vSubjectCols, names(dfSubjects)), collapse = ", ")
    )
  )
  gsm.core::stop_if(
    cnd = !all(c(strSubjectCol, strEventDateCol) %in% names(dfEvents)),
    message = paste0(
      "Columns not found in dfEvents: ",
      paste(
        setdiff(c(strSubjectCol, strEventDateCol), names(dfEvents)),
        collapse = ", "
      )
    )
  )

  if (is.null(strGroupLevel)) {
    strGroupLevel <- strGroupCol
  }

  dfSubj <- dfSubjects %>%
    dplyr::transmute(
      SubjectID = as.character(.data[[strSubjectCol]]),
      GroupID = .data[[strGroupCol]],
      ReferenceDate = as.Date(.data[[strReferenceDateCol]]),
      CensorDays = suppressWarnings(as.numeric(.data[[strCensorCol]]))
    )

  nMissingRef <- sum(is.na(dfSubj$ReferenceDate))
  if (nMissingRef > 0) {
    gsm.core::LogMessage(
      level = "warn",
      message = "{nMissingRef} subject(s) with a missing [ {strReferenceDateCol} ] removed.",
      cli_detail = "alert_warning"
    )
    dfSubj <- dfSubj %>% dplyr::filter(!is.na(.data$ReferenceDate))
  }

  # A missing or negative follow-up duration is treated as no exposure rather
  # than propagated as NA, which Transform_Rate would reject.
  dfSubj <- dfSubj %>%
    dplyr::mutate(
      CensorDays = dplyr::if_else(
        is.na(.data$CensorDays) | .data$CensorDays < 0,
        0,
        .data$CensorDays
      )
    )

  dfFirstEvent <- dfEvents %>%
    dplyr::transmute(
      SubjectID = as.character(.data[[strSubjectCol]]),
      EventDate = as.Date(.data[[strEventDateCol]])
    ) %>%
    dplyr::filter(!is.na(.data$EventDate)) %>%
    dplyr::inner_join(
      dfSubj %>% dplyr::select("SubjectID", "ReferenceDate"),
      by = "SubjectID",
      relationship = "many-to-many"
    ) %>%
    dplyr::mutate(
      EventDays = as.numeric(.data$EventDate - .data$ReferenceDate)
    )

  nPreReference <- sum(dfFirstEvent$EventDays < 0)
  if (nPreReference > 0 && !bIncludePreReferenceEvents) {
    gsm.core::LogMessage(
      level = "info",
      message = "{nPreReference} event(s) dated before [ {strReferenceDateCol} ] ignored.",
      cli_detail = "alert_info"
    )
  }

  dfFirstEvent <- if (bIncludePreReferenceEvents) {
    dplyr::mutate(dfFirstEvent, EventDays = pmax(.data$EventDays, 0))
  } else {
    dplyr::filter(dfFirstEvent, .data$EventDays >= 0)
  }

  # Guard the zero-row case explicitly: dplyr still evaluates `min()` once on an
  # empty group to infer the result type, which warns and yields Inf.
  if (nrow(dfFirstEvent) == 0) {
    dfFirstEvent <- data.frame(
      SubjectID = character(0),
      EventDays = numeric(0)
    )
  } else {
    dfFirstEvent <- dfFirstEvent %>%
      dplyr::group_by(.data$SubjectID) %>%
      dplyr::summarise(EventDays = min(.data$EventDays), .groups = "drop")
  }

  dfInput <- dfSubj %>%
    dplyr::left_join(dfFirstEvent, by = "SubjectID") %>%
    dplyr::mutate(
      Numerator = as.numeric(!is.na(.data$EventDays)),
      # An event recorded after the last known follow-up day is inconsistent;
      # cap exposure at the follow-up duration rather than crediting the site
      # with time it cannot document.
      Denominator = dplyr::if_else(
        is.na(.data$EventDays),
        .data$CensorDays,
        pmin(.data$EventDays, .data$CensorDays)
      )
    )

  nAfterCensor <- sum(
    !is.na(dfInput$EventDays) & dfInput$EventDays > dfInput$CensorDays
  )
  if (nAfterCensor > 0) {
    gsm.core::LogMessage(
      level = "warn",
      message = "{nAfterCensor} event(s) dated after [ {strCensorCol} ] days of follow-up; exposure capped.",
      cli_detail = "alert_warning"
    )
  }

  if (any(is.na(dfInput$GroupID))) {
    gsm.core::LogMessage(
      level = "warn",
      message = "{sum(is.na(dfInput$GroupID))} cases of NA's in GroupID, cases are removed in output",
      cli_detail = "alert_warning"
    )
    dfInput <- dfInput %>% dplyr::filter(!is.na(.data$GroupID))
  }

  dfInput %>%
    dplyr::mutate(
      GroupLevel = strGroupLevel,
      Metric = .data$Numerator / .data$Denominator
    ) %>%
    dplyr::select(
      "SubjectID",
      "GroupID",
      "GroupLevel",
      "Numerator",
      "Denominator",
      "Metric"
    )
}
