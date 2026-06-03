#' Check premature-death window consistency
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Emits a warning when the report's `nWindowDays` disagrees with the window
#' used to produce `dfResults` (detected by comparing the live premature-death
#' count in `Mapped_Death` against the number of `pat0015` `Flag == 2` rows).
#'
#' @param nWindowDays `numeric` Window days passed to the report.
#' @param nPremature `integer` Count of premature deaths in `Mapped_Death`.
#' @param nFlagged `integer` Count of flagged `pat0015` rows in `dfResults`.
#'
#' @return Called for its side-effect (warning); returns `NULL` invisibly.
#' @export
pd_CheckWindowConsistency <- function(nWindowDays, nPremature, nFlagged) {
  warning(
    "Report window (",
    nWindowDays,
    "d) disagrees with the window used to produce dfResults: ",
    nPremature,
    " premature death(s) in Mapped_Death vs ",
    nFlagged,
    " flagged pat0015 row(s). Pass the same nWindowDays used at analysis time (meta.WindowDays).",
    call. = FALSE
  )
  invisible(NULL)
}

#' Premature-death patient listing data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Filters `dfResults` to flagged patient-level premature-death rows
#' (`MetricID == "Analysis_pat0015"`, `Flag == 2`) and joins `Mapped_Death`
#' detail. Sorted by `death_dy` ascending. Missing `death_reason` /
#' `treatment_related` columns degrade to `"Unknown"` / `NA`.
#'
#' @param dfResults `data.frame` Reporting results containing patient-level rows.
#' @param dfDeath `data.frame` Mapped death data keyed on `subjid`.
#' @param dfSubjects `data.frame` (optional) Mapped subject data with `subjid`
#'   and `invid`. When supplied, the output includes `invid` for site-level
#'   filtering in the interactive report.
#'
#' @return A `data.frame` of one row per flagged premature-death subject.
#' @export
pd_PatientListingData <- function(dfResults, dfDeath, dfSubjects = NULL) {
  if (!"death_reason" %in% names(dfDeath)) {
    dfDeath$death_reason <- NA_character_
  }
  if (!"treatment_related" %in% names(dfDeath)) {
    dfDeath$treatment_related <- NA
  }

  df <- dfResults %>%
    dplyr::filter(.data$MetricID == "Analysis_pat0015" & .data$Flag == 2) %>%
    dplyr::transmute(subjid = .data$GroupID, .data$Flag) %>%
    dplyr::left_join(
      dfDeath %>%
        dplyr::select(
          "subjid",
          "death_dt",
          "death_dy",
          "death_reason",
          "treatment_related"
        ),
      by = "subjid"
    ) %>%
    dplyr::mutate(
      death_reason = dplyr::coalesce(.data$death_reason, "Unknown")
    )

  if (!is.null(dfSubjects) && "invid" %in% names(dfSubjects)) {
    df <- df %>%
      dplyr::left_join(
        dfSubjects %>% dplyr::select("subjid", "invid"),
        by = "subjid"
      )
  }

  df %>% dplyr::arrange(.data$death_dy)
}

#' Premature-death patient listing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `DT` table of flagged premature-death subjects.
#'
#' @inheritParams pd_PatientListingData
#'
#' @return A `DT::datatable` htmlwidget.
#' @export
pd_PatientListing <- function(dfResults, dfDeath, dfSubjects = NULL) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfResults),
    message = "dfResults is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  rlang::check_installed("DT", reason = "to run `pd_PatientListing()`")

  dfListing <- pd_PatientListingData(dfResults, dfDeath, dfSubjects)

  col_names <- c(
    "Subject" = "subjid",
    "Flag" = "Flag",
    "Death Date" = "death_dt",
    "Days to Death" = "death_dy",
    "Reason" = "death_reason",
    "Treatment Related" = "treatment_related"
  )

  # Hide invid column if present (used by JS filter, not displayed)
  hidden_cols <- list()
  if ("invid" %in% names(dfListing)) {
    col_names <- c(col_names, "Site" = "invid")
    invid_idx <- which(names(col_names) == "Site") - 1L # 0-indexed
    hidden_cols <- list(list(visible = FALSE, targets = invid_idx))
  }

  DT::datatable(
    dfListing,
    rownames = FALSE,
    colnames = col_names,
    options = list(
      order = list(list(3, "asc")),
      columnDefs = hidden_cols
    )
  )
}
