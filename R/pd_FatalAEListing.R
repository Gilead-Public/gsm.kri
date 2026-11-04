#' Premature-death fatal AE listing data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per qualifying fatal adverse event for participants in the
#' premature-death population (`MetricID == "Analysis_pat0015"`, `Flag == 2` in
#' `dfResults`). An AE qualifies when it is fatal as defined by
#' `pd_SubjectFatalRelatedAE()`: fatal outcome (`aeout`), CTCAE grade 5
#' (`aetoxgr`) or resulted in death (`aesdth`).
#'
#' Only identifiers, the MedDRA preferred term, start date, outcome and
#' relatedness are returned; other AE fields (e.g. cause of death text, drug
#' names) never reach the listing. Missing outcome or relatedness is shown as
#' `"Unknown"`.
#'
#' @inheritParams pd_PatientListingData
#' @param dfAE `data.frame` (optional) Mapped AE data with `subjid` and any of
#'   `mdrpt_nsv`, `aest_dt`, `aeout`, `aetoxgr`, `aesdth`, `aereldrv`, `aerel`
#'   and `studyid`. `NULL` yields an empty listing.
#' @param dfSubjects `data.frame` (optional) Mapped subject data with `subjid`
#'   and any of `studyid`, `invid` and `country`.
#'
#' @return A `data.frame` with `studyid`, `subjid`, `country`, `invid` (each
#'   when available), `mdrpt_nsv`, `aest_dt`, `aeout` and `treatment_related`
#'   (`"Yes"` / `"No"` / `"Unknown"`), sorted by `subjid` and `aest_dt`.
#' @export
pd_FatalAEListingData <- function(dfResults, dfAE = NULL, dfSubjects = NULL) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfResults),
    message = "dfResults is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.null(dfAE) && !is.data.frame(dfAE),
    message = "dfAE is not a data.frame"
  )

  premature <- dfResults %>%
    dplyr::filter(.data$MetricID == "Analysis_pat0015" & .data$Flag == 2) %>%
    dplyr::pull("GroupID")

  if (is.null(dfAE)) {
    dfAE <- tibble::tibble(subjid = character(0))
  }
  for (col in c("mdrpt_nsv", "aest_dt", "aeout")) {
    if (!col %in% names(dfAE)) {
      dfAE[[col]] <- rep(NA, nrow(dfAE))
    }
  }

  subject_cols <- if (!is.null(dfSubjects)) {
    intersect(c("studyid", "invid", "country"), names(dfSubjects))
  } else {
    character(0)
  }

  df <- dfAE %>%
    dplyr::filter(.data$subjid %in% premature) %>%
    pd_FlagFatalAE() %>%
    dplyr::filter(.data$.fatal) %>%
    dplyr::transmute(
      dplyr::across(dplyr::any_of(setdiff("studyid", subject_cols))),
      subjid = as.character(.data$subjid),
      mdrpt_nsv = as.character(.data$mdrpt_nsv),
      aest_dt = .data$aest_dt,
      aeout = dplyr::coalesce(as.character(.data$aeout), "Unknown"),
      treatment_related = dplyr::coalesce(.data$.related, "Unknown")
    )

  if (length(subject_cols) > 0) {
    df <- df %>%
      dplyr::left_join(
        dfSubjects %>%
          dplyr::select("subjid", dplyr::all_of(subject_cols)) %>%
          dplyr::distinct(.data$subjid, .keep_all = TRUE),
        by = "subjid"
      )
  }

  df %>%
    dplyr::relocate(dplyr::any_of("studyid")) %>%
    dplyr::relocate(dplyr::any_of(c("country", "invid")), .after = "subjid") %>%
    dplyr::arrange(.data$subjid, .data$aest_dt)
}

#' Premature-death fatal AE listing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `DT` table of qualifying fatal adverse events for premature-death
#' participants. See `pd_FatalAEListingData()`.
#'
#' @inheritParams pd_FatalAEListingData
#'
#' @return A `DT::datatable` htmlwidget.
#' @export
pd_FatalAEListing <- function(dfResults, dfAE = NULL, dfSubjects = NULL) {
  rlang::check_installed("DT", reason = "to run `pd_FatalAEListing()`")

  dfListing <- pd_FatalAEListingData(dfResults, dfAE, dfSubjects)

  col_names <- c(
    "Study" = "studyid",
    "Subject" = "subjid",
    "Country" = "country",
    "Site" = "invid",
    "AE Term (MedDRA PT)" = "mdrpt_nsv",
    "AE Start Date" = "aest_dt",
    "AE Outcome" = "aeout",
    "Treatment Related" = "treatment_related"
  )
  col_names <- col_names[col_names %in% names(dfListing)]

  # Same invid column name as pd_PatientListing(), so the report's
  # country/site filter drives this table too.
  column_defs <- list()
  if ("invid" %in% names(dfListing)) {
    column_defs <- list(list(
      name = "invid",
      targets = which(names(dfListing) == "invid") - 1L
    ))
  }

  DT::datatable(
    dfListing,
    rownames = FALSE,
    colnames = col_names,
    extensions = "Buttons",
    options = list(
      dom = "Blfrtip",
      buttons = list(list(
        extend = "csv",
        text = "Download CSV",
        exportOptions = list(modifier = list(search = "applied"))
      )),
      columnDefs = column_defs
    )
  )
}
