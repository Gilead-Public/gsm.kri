#' Participant listing rows for the IP Monitoring report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per participant in status stack order, then participant ID. The
#' `dosed` column is hidden in the table and drives its dosed filter.
#'
#' @param dfIPM `data.frame` Output of [ipm_ClassifyParticipants()].
#'
#' @return A `tibble` with the listing columns in display order.
#' @keywords internal
#' @export
ipm_ListingData <- function(dfIPM) {
  status <- as.character(dfIPM$status)
  bUnrecognized <- status %in% "Unrecognized status"
  status[bUnrecognized] <- paste0(
    "Unrecognized status: ",
    dplyr::coalesce(dfIPM$status_raw[bUnrecognized], "missing")
  )
  bDiscontinued <- dfIPM$status %in%
    c(
      "Premature treatment discontinuation",
      "Potential premature treatment discontinuation"
    )
  reason <- dplyr::na_if(trimws(dfIPM$ptd_reason), "")
  df <- tibble::tibble(
    subjid = dfIPM$subjid,
    invid = dfIPM$invid,
    country = dfIPM$country,
    status = status,
    kit_assigned = dplyr::coalesce(dfIPM$kit_assigned, ""),
    first_dose_dt = dfIPM$first_dose_dt,
    days_to_first_dose = dfIPM$days_to_first_dose,
    days_to_event = dfIPM$days_to_event,
    study_complete = dfIPM$study_complete,
    consent_withdrawn = dfIPM$consent_withdrawn,
    drg_completion = dfIPM$drg_completion,
    ptd_reason = ifelse(
      bDiscontinued,
      dplyr::coalesce(reason, "Not yet recorded"),
      ""
    ),
    dosed = dfIPM$dosed
  )
  df[order(as.integer(dfIPM$status), dfIPM$subjid, method = "radix"), ]
}

#' Participant listing table for the IP Monitoring report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A `DT` table with a search box and a CSV button. The report's filter script
#' searches the named `dosed`, `country` and `invid` columns. The CSV holds
#' every participant whatever the filters and search.
#'
#' @param dfListing `data.frame` Output of [ipm_ListingData()].
#'
#' @return A `DT` htmlwidget with element id `ipc-listing`.
#' @keywords internal
#' @export
ipm_Listing <- function(dfListing) {
  vLabels <- c(
    "Participant ID" = "subjid",
    "Investigator ID" = "invid",
    "Country" = "country",
    "Status" = "status",
    "Kit assigned" = "kit_assigned",
    "First dose date" = "first_dose_dt",
    "Days from enrollment to first dose" = "days_to_first_dose",
    "Days to event or today" = "days_to_event",
    "Study complete" = "study_complete",
    "Consent withdrawn" = "consent_withdrawn",
    "Study Drug Completed per Protocol" = "drg_completion",
    "Drug discontinuation reason" = "ptd_reason",
    "dosed" = "dosed"
  )
  target <- function(col) which(names(dfListing) == col) - 1L
  DT::datatable(
    dfListing,
    elementId = "ipc-listing",
    rownames = FALSE,
    colnames = vLabels[vLabels %in% names(dfListing)],
    extensions = "Buttons",
    options = list(
      dom = "Blfrtip",
      buttons = list(list(
        extend = "csv",
        text = "Download CSV",
        filename = "ip-monitoring-participants",
        exportOptions = list(
          modifier = list(search = "none"),
          columns = ":visible"
        )
      )),
      columnDefs = list(
        list(targets = target("invid"), name = "invid"),
        list(targets = target("country"), name = "country"),
        list(targets = target("dosed"), name = "dosed", visible = FALSE)
      )
    )
  )
}
