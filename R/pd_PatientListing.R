#' Check premature-death window consistency
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Warns only when the report's `nWindowDays` disagrees with the window used to
#' produce `dfResults` -- i.e. when the live premature-death count in
#' `Mapped_Death` (`nPremature`) differs from the number of `pat0015`
#' `Flag == 2` rows (`nFlagged`). When the counts agree it returns invisibly
#' without warning, so callers (e.g. the report) just call it unconditionally.
#'
#' @param nWindowDays `numeric` Window days passed to the report.
#' @param nPremature `integer` Count of premature deaths in `Mapped_Death`.
#' @param nFlagged `integer` Count of flagged `pat0015` rows in `dfResults`.
#'
#' @return Called for its side-effect (warning on mismatch); returns `NULL` invisibly.
#' @export
pd_CheckWindowConsistency <- function(nWindowDays, nPremature, nFlagged) {
  if (nFlagged != nPremature) {
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
  }
  invisible(NULL)
}

#' Premature-death patient listing data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Filters `dfResults` to flagged patient-level premature-death rows
#' (`MetricID == "Analysis_pat0015"`, `Flag == 2`) and joins `Mapped_Death`
#' detail. Sorted by `death_dy` ascending. `death_reason` is the death
#' classification (`deathcls`), falling back to `"Unknown"` when absent.
#' `treatment_related` is three-valued: `"Yes"` when `deathcls` is an adverse
#' event AND the subject has a fatal (grade 5) treatment-related AE in `dfAE`;
#' `"No"` when `deathcls` is an adverse event AND the subject has a fatal
#' (grade 5) not-treatment-related AE, or when `deathcls` is not an adverse
#' event AND no fatal treatment-related AE exists;
#' `"Unknown"` otherwise (mixed signals, or missing `deathcls`/AE evidence).
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
#' @param dfExclusion `data.frame` (optional) Mapped exclusion data with `subjid`
#'   and `Source` (as produced by `EXCLUSION.yaml`). When supplied with a
#'   `Source` column, the output gains a three-valued `eligibility_status`
#'   column: `"Ineligible"` when `Source != "Neither"` (matching the `kri0014`
#'   rule), `"Eligible"` when `Source == "Neither"`, and `"Unknown"` when the
#'   subject has no matching exclusion row.
#' @param dfAE `data.frame` (optional) Mapped AE data with `subjid`, `aetoxgr`,
#'   and `aerel` (`"RELATED"`/`"NOT RELATED"`). Used to compute the Treatment
#'   Related column: `"Yes"` when `deathcls` is an adverse event AND the subject
#'   has a fatal (`aetoxgr==5`) treatment-related AE; `"No"` when `deathcls` is
#'   an adverse event AND the subject has a fatal (`aetoxgr==5`) not-treatment-related
#'   AE, or when `deathcls` is not an AE AND there is no fatal treatment-related
#'   AE; `"Unknown"` otherwise (mixed signals, or missing `deathcls`/AE
#'   evidence). `death_reason` is `deathcls` (else `"Unknown"`).
#'
#' @return A `data.frame` of one row per flagged premature-death subject.
#' @export
pd_PatientListingData <- function(
  dfResults,
  dfDeath,
  dfSubjects = NULL,
  dfExclusion = NULL,
  dfAE = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfResults),
    message = "dfResults is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )

  if (!"deathcls" %in% names(dfDeath)) {
    dfDeath[["deathcls"]] <- NA_character_
  }

  # AE-side signal: a fatal (aetoxgr==5) treatment-related (aerel=="RELATED") AE.
  # Absent dfAE -> nobody qualifies (everything resolves via deathcls alone).
  dfFatalRel <- if (!is.null(dfAE) && is.data.frame(dfAE)) {
    pd_SubjectFatalRelatedAE(dfAE)
  } else {
    tibble::tibble(
      subjid = character(0),
      has_fatal_related_ae = logical(0),
      has_fatal_unrelated_ae = logical(0)
    )
  }

  df <- dfResults %>%
    dplyr::filter(.data$MetricID == "Analysis_pat0015" & .data$Flag == 2) %>%
    dplyr::transmute(subjid = .data$GroupID) %>%
    dplyr::left_join(
      dfDeath %>%
        dplyr::select("subjid", "death_dt", "death_dy", "deathcls"),
      by = "subjid"
    ) %>%
    dplyr::left_join(dfFatalRel, by = "subjid") %>%
    dplyr::mutate(
      # death_reason is the death classification (SI-3); pd_DeathReason is the
      # single source of truth for the "Unknown" fallback (NA/blank/whitespace).
      death_reason = pd_DeathReason(dplyr::pick("deathcls")),
      # death_dy was defined upstream as death_dt - rgmn_dt, so this reconstructs
      # the randomization date.
      randomization_date = .data$death_dt - .data$death_dy,
      # Treatment Related: deathcls is the AE-death gate; a fatal treatment-related
      # AE is the relatedness evidence. Both positive -> Yes; AE death + fatal
      # not-related AE -> No; both negative -> No; mixed or missing -> Unknown.
      treatment_related = dplyr::case_when(
        is.na(.data$deathcls) | trimws(.data$deathcls) == "" ~ "Unknown",
        grepl("a(dverse[ ]*)?e", .data$deathcls, ignore.case = TRUE) &
          dplyr::coalesce(.data$has_fatal_related_ae, FALSE) ~ "Yes",
        grepl("a(dverse[ ]*)?e", .data$deathcls, ignore.case = TRUE) &
          dplyr::coalesce(.data$has_fatal_unrelated_ae, FALSE) ~ "No",
        !grepl("a(dverse[ ]*)?e", .data$deathcls, ignore.case = TRUE) &
          !dplyr::coalesce(.data$has_fatal_related_ae, FALSE) ~ "No",
        TRUE ~ "Unknown"
      )
    ) %>%
    dplyr::select(
      -dplyr::any_of(c("has_fatal_related_ae", "has_fatal_unrelated_ae"))
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

  if (!is.null(dfExclusion) && "Source" %in% names(dfExclusion)) {
    df <- df %>%
      dplyr::left_join(
        # distinct() guards against listing-row fan-out: Mapped_EXCLUSION is
        # one-row-per-subject by construction (EXCLUSION.yaml groups by subjid;
        # kri0014 consumes it as a per-subject denominator), but never let an
        # unexpected duplicate multiply a subject's death-listing row.
        dfExclusion %>%
          dplyr::select("subjid", "Source") %>%
          dplyr::distinct(.data$subjid, .keep_all = TRUE),
        by = "subjid"
      ) %>%
      dplyr::mutate(
        # Canonical eligibility rule (kri0014), shared via pd_EligibilityStatus()
        # so the patient listing and the Overview table cannot drift. NA Source =
        # subject has no Mapped_EXCLUSION row => Unknown (never assert eligibility
        # we cannot confirm).
        eligibility_status = pd_EligibilityStatus(.data$Source)
      ) %>%
      dplyr::select(-"Source")
  }

  df %>%
    dplyr::relocate(dplyr::any_of("studyid")) %>%
    dplyr::relocate(dplyr::any_of(c("country", "invid")), .after = "subjid") %>%
    dplyr::relocate("randomization_date", .before = "death_dt") %>%
    dplyr::select(-dplyr::any_of(c("deathcls", "aerel"))) %>%
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
pd_PatientListing <- function(
  dfResults,
  dfDeath,
  dfSubjects = NULL,
  dfExclusion = NULL,
  dfAE = NULL
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfResults),
    message = "dfResults is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  rlang::check_installed("DT", reason = "to run `pd_PatientListing()`")

  dfListing <- pd_PatientListingData(
    dfResults,
    dfDeath,
    dfSubjects,
    dfExclusion,
    dfAE
  )

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
  if ("eligibility_status" %in% names(dfListing)) {
    col_names <- c(col_names, "Eligibility Status" = "eligibility_status")
  }

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
