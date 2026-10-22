#' IP Compliance status vocabulary
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Status labels in stack order (bottom to top) with their colours. The three
#' not-dosed labels must equal the `ipns_status` values gsm.mapping's IPNS
#' mapping emits; the four dosed labels follow `drv_drg_completion`.
#'
#' @return Named `character` vector of hex colours.
#' @keywords internal
#' @export
ipc_StatusColors <- function() {
  c(
    "Potential IP non-starter - within window" = "#EDA100",
    "Potential IP non-starter - outside window" = "#EB6834",
    "Confirmed IP non-starter" = "#C62F4B",
    "Premature treatment discontinuation" = "#111111",
    "Potential premature treatment discontinuation" = "#5F6B7A",
    # Before the treatment statuses so they end the stack; gsm.viz only draws
    # it when present.
    "Unrecognized status" = "#9AA4B2",
    "Treatment ongoing" = "#8CCB7E",
    "Treatment complete per protocol" = "#1E7B3C"
  )
}

#' Classify enrolled participants for the IP Compliance report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per enrolled participant with their status, dosed flag, event date
#' and day counts. Every chart, the overview and the listing read this frame.
#' Data conflicts are reported as warnings naming the participants.
#'
#' @param dfIPNS `data.frame` `Mapped_IPNS`.
#' @param dfSubj `data.frame` `Mapped_SUBJ`, the source of
#'   `drv_drg_completion` and the treatment discontinuation date and reason.
#'   `NULL`, or a frame without `drv_drg_completion`, leaves every dosed
#'   participant Unrecognized.
#' @param dfStudComp `data.frame` `Mapped_STUDCOMP`, or `NULL`.
#' @param dSnapshotDate `Date` "Today" for the day counts.
#'
#' @return A `tibble` with one row per participant.
#' @keywords internal
#' @export
ipc_ClassifyParticipants <- function(
  dfIPNS,
  dfSubj = NULL,
  dfStudComp = NULL,
  dSnapshotDate
) {
  gsm.core::stop_if(
    cnd = !(inherits(dSnapshotDate, "Date") &&
      length(dSnapshotDate) == 1 &&
      !is.na(dSnapshotDate)),
    message = "dSnapshotDate must be a single Date"
  )
  # Without ipns_status the mapping predates the labelled IPNS contract;
  # carrying on would turn every not-dosed participant Unrecognized.
  vMissing <- setdiff(
    c(
      "subjid",
      "drv_ip_dosed",
      "ipns_status_ord",
      "ipns_status",
      "drv_enrollment_dt"
    ),
    names(dfIPNS)
  )
  gsm.core::stop_if(
    cnd = length(vMissing) > 0,
    message = paste0(
      "dfIPNS lacks ",
      paste(vMissing, collapse = ", "),
      ": map it with a gsm.mapping IPNS workflow that labels the status"
    )
  )

  bHasPTD <- !is.null(dfSubj) && "drv_drg_completion" %in% names(dfSubj)
  df <- ipc_Dedupe(dfIPNS, "Mapped_IPNS")
  vSubjCols <- c(
    if (!is.null(dfSubj)) {
      intersect(
        c(
          "drv_drg_completion",
          "drv_treatment_discontinuation_dt",
          "drv_premature_discontinuation_reason"
        ),
        names(dfSubj)
      )
    },
    # The IPNS query may drop drv_kit_assigned; SUBJ still carries it.
    if (!"drv_kit_assigned" %in% names(df) && !is.null(dfSubj)) {
      intersect("drv_kit_assigned", names(dfSubj))
    }
  )
  if (length(vSubjCols) > 0) {
    dfSubj <- ipc_Dedupe(dfSubj, "Mapped_SUBJ")
    df <- dplyr::left_join(df, dfSubj[c("subjid", vSubjCols)], by = "subjid")
  }
  df <- dplyr::left_join(df, ipc_StudCompSummary(dfStudComp), by = "subjid")

  col <- function(name) {
    if (name %in% names(df)) df[[name]] else rep(NA, nrow(df))
  }
  vLabels <- names(ipc_StatusColors())
  dosed <- toupper(trimws(as.character(df$drv_ip_dosed)))
  dosed[!dosed %in% c("Y", "N")] <- NA
  ord <- suppressWarnings(as.integer(df$ipns_status_ord))
  bKnownLabel <- df$ipns_status %in% vLabels
  dPTD <- ipc_AsDate(col("drv_treatment_discontinuation_dt"))
  drg <- as.character(col("drv_drg_completion"))
  bNullDrg <- is.na(drg) | drg == ""
  vDosedStatus <- c(
    N = "Premature treatment discontinuation",
    "Potential No" = "Potential premature treatment discontinuation",
    Y = "Treatment complete per protocol"
  )
  status <- dplyr::case_when(
    dosed %in% "Y" & !bHasPTD ~ "Unrecognized status",
    dosed %in% "Y" & bNullDrg ~ "Treatment ongoing",
    dosed %in% "Y" & drg %in% names(vDosedStatus) ~
      unname(vDosedStatus[drg]),
    dosed %in% "N" & ord %in% 1:3 & bKnownLabel ~ as.character(df$ipns_status),
    TRUE ~ "Unrecognized status"
  )
  dEnrollment <- ipc_AsDate(df$drv_enrollment_dt)
  # Study completion no longer dates a dosed participant; without a
  # discontinuation date the point sits on the diagonal.
  dEvent <- dplyr::case_when(
    dosed %in% "Y" ~ dPTD,
    status == "Confirmed IP non-starter" ~ df$confirm_dt,
    TRUE ~ as.Date(NA)
  )
  # Inclusive day counts: an event on the enrollment day is day 1.
  day_count <- function(d) as.integer(d - dEnrollment) + 1L
  nDaysSinceEnrl <- day_count(dSnapshotDate)

  id <- df$subjid
  ipc_Warn(
    is.na(dosed),
    id,
    "drv_ip_dosed is not Y or N, so the status is Unrecognized for"
  )
  ipc_Warn(
    dosed %in% "N" & ord %in% 0L,
    id,
    "Not dosed with the Dosed IP non-starter status, so the status is Unrecognized for"
  )
  ipc_Warn(
    dosed %in% "Y" & ord %in% 1:3,
    id,
    "Dosed with a not-dosed IP non-starter status; the dosed flag wins for"
  )
  ipc_Warn(
    dosed %in% "N" & !is.na(dPTD),
    id,
    "Not dosed with a treatment discontinuation date; the date is ignored for"
  )
  ipc_Warn(
    dosed %in% "N" & !bNullDrg,
    id,
    "Not dosed with a drv_drg_completion value; the value is ignored for"
  )
  ipc_Warn(
    dosed %in% "Y" & bHasPTD & !bNullDrg & !drg %in% names(vDosedStatus),
    id,
    "drv_drg_completion is not Y, N or Potential No, so the status is Unrecognized for"
  )
  ipc_Warn(
    dosed %in% "N" & ord %in% 1:3 & !bKnownLabel,
    id,
    "ipns_status is not a report status label, so the status is Unrecognized for"
  )
  ipc_Warn(
    status == "Confirmed IP non-starter" & is.na(dEvent),
    id,
    "No event date, so the time-to-event point sits on the diagonal for"
  )
  ipc_Warn(
    is.na(dEnrollment),
    id,
    "No enrollment date, so there are no day counts or time-to-event point for"
  )
  ipc_Warn(
    !is.na(dEvent) & (dEvent < dEnrollment | dEvent > dSnapshotDate),
    id,
    "Event date before enrollment or after the snapshot date for"
  )

  bDiscontinued <- status %in% vDosedStatus[c("N", "Potential No")]
  tibble::tibble(
    subjid = as.character(df$subjid),
    studyid = as.character(col("studyid")),
    invid = pd_CountryLabel(col("invid")),
    country = pd_CountryLabel(col("country")),
    dosed = dosed,
    status = factor(status, levels = vLabels),
    # The listing names the delivered value behind an Unrecognized status.
    status_raw = ifelse(
      dosed %in% "Y",
      drg,
      as.character(col("drv_ip_nonstarter_status"))
    ),
    enrollment_dt = dEnrollment,
    first_dose_dt = ipc_AsDate(col("drv_ip_first_dose_dt")),
    event_dt = dEvent,
    days_since_enrl = nDaysSinceEnrl,
    days_to_event = dplyr::coalesce(day_count(dEvent), nDaysSinceEnrl),
    days_to_first_dose = day_count(ipc_AsDate(col("drv_ip_first_dose_dt"))),
    kit_assigned = as.character(col("drv_kit_assigned")),
    study_complete = dplyr::coalesce(df$study_complete, ""),
    consent_withdrawn = ifelse(df$consent_withdrawn %in% TRUE, "Y", "N"),
    drg_completion = ifelse(dosed %in% "Y" & !bNullDrg, drg, ""),
    ptd_reason = ifelse(
      bDiscontinued,
      as.character(col("drv_premature_discontinuation_reason")),
      NA_character_
    )
  )
}

# One row per participant: several completion records are allowed, the
# earliest qualifying record dates the event, and any Y answer completes the
# study.
ipc_StudCompSummary <- function(dfStudComp = NULL) {
  if (is.null(dfStudComp) || nrow(dfStudComp) == 0) {
    return(tibble::tibble(
      subjid = character(),
      study_complete = character(),
      confirm_dt = as.Date(character()),
      consent_withdrawn = logical()
    ))
  }
  first_date <- function(x) {
    if (all(is.na(x))) as.Date(NA) else min(x, na.rm = TRUE)
  }
  tibble::tibble(
    subjid = dfStudComp$subjid,
    cy = toupper(trimws(dfStudComp$compyn)),
    d = ipc_AsDate(dfStudComp$mincreated_dts),
    withdrew = toupper(trimws(dfStudComp$compreas)) %in% "WITHDREW CONSENT"
  ) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      study_complete = dplyr::case_when(
        any(.data$cy %in% "Y") ~ "Y",
        any(.data$cy %in% "N") ~ "N",
        TRUE ~ ""
      ),
      confirm_dt = first_date(.data$d[!is.na(.data$cy) & .data$cy != ""]),
      consent_withdrawn = any(.data$withdrew),
      .groups = "drop"
    )
}

# as.Date() converts date-times in UTC, which moves a late-evening timestamp of
# a non-UTC column onto the next day; format() keeps its own calendar date.
ipc_AsDate <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(as.Date(format(x, "%Y-%m-%d")))
  }
  as.Date(x)
}

ipc_Dedupe <- function(df, strName) {
  bDuplicate <- duplicated(df$subjid)
  ipc_Warn(
    bDuplicate,
    df$subjid,
    paste(strName, "has duplicate rows; the first row is kept for")
  )
  df[!bDuplicate, , drop = FALSE]
}

# One warning per data check, naming at most ten participants so a large study
# does not flood the log.
ipc_Warn <- function(vFlag, vSubjid, strMessage) {
  ids <- unique(vSubjid[vFlag %in% TRUE])
  if (length(ids) == 0) {
    return(invisible())
  }
  shown <- paste(utils::head(ids, 10), collapse = ", ")
  more <- if (length(ids) > 10) {
    sprintf(" and %d more", length(ids) - 10)
  } else {
    ""
  }
  cli::cli_warn("{strMessage}: {shown}{more}.")
}
