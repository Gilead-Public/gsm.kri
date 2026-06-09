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
#' A `randomization_date` column is derived as `death_dt - death_dy`,
#' reconstructing the randomization date (`rgmn_dt`) that `death_dy` was counted from.
#'
#' @param dfResults `data.frame` Reporting results containing patient-level rows.
#' @param dfDeath `data.frame` Mapped death data keyed on `subjid`.
#' @param dfSubjects `data.frame` (optional) Mapped subject data with `subjid`,
#'   `invid`, and optionally `studyid` / `country`. When supplied, the output
#'   includes `studyid` (when present, as the leftmost column), `invid`, and
#'   `country` (when present) as visible columns for study-, site-, and
#'   country-level filtering in the interactive report.
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
    dplyr::transmute(subjid = .data$GroupID) %>%
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
      death_reason = dplyr::coalesce(.data$death_reason, "Unknown"),
      # death_dy was defined upstream (complete_death) as death_dt - rgmn_dt, the
      # randomization date, so this subtraction reconstructs that exact date.
      randomization_date = .data$death_dt - .data$death_dy
    )

  if (
    !is.null(dfSubjects) &&
      any(c("studyid", "invid", "country") %in% names(dfSubjects))
  ) {
    df <- df %>%
      dplyr::left_join(
        dfSubjects %>%
          dplyr::select(
            "subjid",
            dplyr::any_of(c("studyid", "invid", "country"))
          ),
        by = "subjid"
      )
  }

  df %>%
    dplyr::relocate(dplyr::any_of("studyid")) %>%
    dplyr::relocate(dplyr::any_of(c("country", "invid")), .after = "subjid") %>%
    dplyr::relocate("randomization_date", .before = "death_dt") %>%
    dplyr::arrange(.data$death_dy)
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

  col_names <- character(0)
  if ("studyid" %in% names(dfListing)) {
    col_names <- c(col_names, "Study" = "studyid")
  }
  col_names <- c(col_names, "Subject" = "subjid")
  if ("country" %in% names(dfListing)) {
    col_names <- c(col_names, "Country" = "country")
  }
  if ("invid" %in% names(dfListing)) {
    col_names <- c(col_names, "Site" = "invid")
  }
  col_names <- c(
    col_names,
    "Randomization Date" = "randomization_date",
    "Death Date" = "death_dt",
    "Days to Death" = "death_dy",
    "Reason" = "death_reason",
    "Treatment Related" = "treatment_related"
  )

  # Stamp the DataTables column name so the report's JS site-filter binds with
  # column("invid:name") instead of a hardcoded position. The Site column is now
  # visible (no visible = FALSE def).
  column_defs <- list()
  if ("invid" %in% names(dfListing)) {
    column_defs <- list(list(
      name = "invid",
      targets = which(names(dfListing) == "invid") - 1L
    ))
  }

  # CSV export via the DataTables Buttons extension (bundled with DT, no JSZip
  # needed for CSV). `search = "applied"` makes the download follow the report's
  # active country/site column filter, so the CSV matches what's on screen.
  DT::datatable(
    dfListing,
    rownames = FALSE,
    colnames = col_names,
    extensions = "Buttons",
    options = list(
      # dom letters: B=buttons, l=length menu ("Show N entries"), f=filter,
      # r=processing, t=table, i=info, p=pagination. Keep `l` so the length
      # dropdown stays alongside the Buttons bar.
      dom = "Blfrtip",
      buttons = list(list(
        extend = "csv",
        text = "Download CSV",
        exportOptions = list(modifier = list(search = "applied"))
      )),
      order = list(list(which(names(dfListing) == "death_dy") - 1L, "asc")),
      columnDefs = column_defs
    )
  )
}
