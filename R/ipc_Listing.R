#' Participant listing rows for the IP Compliance report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per participant in status stack order, then participant ID. The
#' `dosed` column is hidden in the table and drives its dosed filter.
#'
#' @param dfIPC `data.frame` Output of [ipc_ClassifyParticipants()].
#' @param bHasPTD `logical` Whether premature treatment discontinuation data
#'   was delivered. When `FALSE`, the discontinuation columns are blank.
#'
#' @return A `tibble` with the listing columns in display order.
#' @keywords internal
#' @export
ipc_ListingData <- function(dfIPC, bHasPTD) {
  status <- as.character(dfIPC$status)
  bUnrecognized <- status %in% "Unrecognized status"
  status[bUnrecognized] <- paste0(
    "Unrecognized status: ",
    dplyr::coalesce(dfIPC$status_raw[bUnrecognized], "missing")
  )
  bPTD <- dfIPC$ptd_flag %in% "Y"
  reason <- dplyr::na_if(trimws(dfIPC$ptd_reason), "")
  df <- tibble::tibble(
    subjid = dfIPC$subjid,
    invid = dfIPC$invid,
    country = dfIPC$country,
    status = status,
    kit_assigned = dplyr::coalesce(dfIPC$kit_assigned, ""),
    first_dose_dt = dfIPC$first_dose_dt,
    days_to_first_dose = dfIPC$days_to_first_dose,
    days_since_enrl = dfIPC$days_since_enrl,
    days_to_event = dfIPC$days_to_event,
    consent_withdrawn = dfIPC$consent_withdrawn,
    ptd_flag = if (bHasPTD) dfIPC$ptd_flag else "",
    ptd_reason = ifelse(bPTD, dplyr::coalesce(reason, "Not yet recorded"), ""),
    dosed = dfIPC$dosed
  )
  df[order(as.integer(dfIPC$status), dfIPC$subjid, method = "radix"), ]
}

#' Participant listing table for the IP Compliance report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A `DT` table with a search box and a CSV button. The report's filter script
#' searches the named `dosed`, `country` and `invid` columns. The CSV holds
#' every participant whatever the filters and search.
#'
#' @param dfListing `data.frame` Output of [ipc_ListingData()].
#'
#' @return A `DT` htmlwidget with element id `ipc-listing`.
#' @keywords internal
#' @export
ipc_Listing <- function(dfListing) {
  vLabels <- c(
    "Participant ID" = "subjid",
    "Investigator ID" = "invid",
    "Country" = "country",
    "Status" = "status",
    "Kit assigned" = "kit_assigned",
    "First dose date" = "first_dose_dt",
    "Days from enrollment to first dose" = "days_to_first_dose",
    "Days since enrollment" = "days_since_enrl",
    "Days to event or today" = "days_to_event",
    "Consent withdrawn" = "consent_withdrawn",
    "Premature treatment discontinuation" = "ptd_flag",
    "Discontinuation reason" = "ptd_reason",
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
        filename = "ip-compliance-participants",
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
