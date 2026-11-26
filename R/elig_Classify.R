# Eligibility report: participant status, flag sources and
# criteria, derived once in R. Every chart, card and listing reads the frame of
# elig_ClassifyParticipants(); the report's JavaScript only filters it.

ELIG_INELIGIBLE <- "Ineligible"
ELIG_POTENTIAL <- "Potentially Ineligible"
ELIG_NO_RISK <- "No Eligibility Risk"

ELIG_RATE_METRIC_ID <- "Analysis_qtl0001"

ELIG_UNKNOWN <- "Unknown"

# Flag columns of the classified frame, with their display names. Basic mode
# shows one PD source; the Important / Non-important split replaces it when the
# study delivers both columns.
ELIG_SOURCES <- c(
  flag_pd = "Protocol Deviation",
  flag_pd_important = "Important PD",
  flag_pd_nonimportant = "Non-important PD",
  flag_ecrf = "EDC eCRF",
  flag_edc_query = "EDC Query",
  flag_edc_pd = "EDC PD"
)

#' Eligibility status colours
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Standard gsm flag palette, keyed by status in chart stack order (first is
#' the base of the bar).
#'
#' @param bPilot `logical` Include Potentially Ineligible. Default: `TRUE`.
#'
#' @return Named `character` of hex colours.
#'
#' @keywords internal
#' @export
elig_StatusColors <- function(bPilot = TRUE) {
  colors <- stats::setNames(
    c("#FF5859", "#FEAA02", "#3DAF06"),
    c(ELIG_INELIGIBLE, ELIG_POTENTIAL, ELIG_NO_RISK)
  )
  if (isTRUE(bPilot)) colors else colors[c(ELIG_INELIGIBLE, ELIG_NO_RISK)]
}

#' Eligibility report mode
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The study picks the mode with `strMode`. Pilot mode falls back to basic,
#' with a warning, when neither `edc_query` nor `edc_pd` has data: a pilot
#' report with no EDC source would show only N/A columns.
#'
#' @param dfExclusion `data.frame` `Mapped_EXCLUSION`.
#' @param strMode `character` `"basic"` (default) or `"pilot"`.
#'
#' @return `character` `"basic"` or `"pilot"`.
#'
#' @keywords internal
#' @export
elig_Mode <- function(dfExclusion, strMode = c("basic", "pilot")) {
  strMode <- match.arg(strMode)
  bData <- any(vapply(
    c("edc_query", "edc_pd"),
    function(x) x %in% names(dfExclusion) && !all(is.na(dfExclusion[[x]])),
    logical(1)
  ))
  if (strMode == "pilot" && !bData) {
    cli::cli_warn("Pilot mode needs EDC Query or EDC PD data; neither has any, so the basic report is rendered.")
    return("basic")
  }
  strMode
}

#' Classify enrolled participants by eligibility status
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per enrolled participant of `Mapped_EXCLUSION` with exactly one
#' status:
#' - **Ineligible**: `Source != 'Neither'` (EDC eCRF and PD rules, applied upstream);
#' - **Potentially Ineligible** (pilot mode only): otherwise, the `edc_query`
#'   or `edc_pd` flag is `"Y"` (EDC Query and EDC PD rules, applied in the study's mapping);
#' - **No Eligibility Risk**: otherwise.
#'
#' The flag sources never read `Source` values: the EDC eCRF flag is
#' `ie_violation`, the PD flag is `pd_violation`, or the presence of PD terms
#' (`eligibility_criteria`) when a study's EXCLUSION has no `pd_violation`.
#'
#' @param dfExclusion `data.frame` `Mapped_EXCLUSION`, optionally with the
#'   level 1 columns `pd_important`, `pd_nonimportant`, `edc_query` and
#'   `edc_pd` (`"Y"`/`"N"`; `NA` throughout when the source is not delivered),
#'   and `iecat_concat`, the category (`"IN"`/`"EX"`) of each code in
#'   `ietestcd_concat` order; without it the criteria are not split by type.
#' @param dfGroups `data.frame` Reporting groups. Site-level
#'   `InvestigatorFirstName` / `InvestigatorLastName` give the investigator.
#'   Default: `NULL`.
#' @param strMode `character` Mode resolved by [elig_Mode()]: `"basic"`
#'   (default) or `"pilot"`.
#'
#' @return `tibble` with `studyid`, `subjid`, `country`, `invid`,
#'   `investigator`, `status`, the `flag_*` columns of the delivered sources
#'   (`"Y"`/`"N"`/`NA`), `criteria`, `criteria_type`, `pd_dates` and
#'   `pd_terms`.
#'
#' @keywords internal
#' @export
elig_ClassifyParticipants <- function(dfExclusion, dfGroups = NULL, strMode = c("basic", "pilot")) {
  bPilot <- match.arg(strMode) == "pilot"
  col <- function(name) {
    if (name %in% names(dfExclusion)) as.character(dfExclusion[[name]]) else rep(NA_character_, nrow(dfExclusion))
  }
  yn <- function(x) ifelse(!is.na(x) & toupper(x) == "Y", "Y", "N")
  source <- col("Source")
  bIneligible <- !is.na(source) & source != "Neither"

  pd <- if ("pd_violation" %in% names(dfExclusion)) {
    yn(col("pd_violation"))
  } else {
    ifelse(!is.na(col("eligibility_criteria")) & nzchar(col("eligibility_criteria")), "Y", "N")
  }

  df <- tibble::tibble(
    studyid = col("studyid"),
    subjid = col("subjid"),
    country = dplyr::coalesce(col("country"), ELIG_UNKNOWN),
    invid = dplyr::coalesce(col("invid"), ELIG_UNKNOWN),
    flag_pd = pd,
    flag_ecrf = yn(col("ie_violation")),
    criteria = col("ietestcd_concat"),
    criteria_type = col("iecat_concat"),
    pd_dates = col("dvdtm"),
    pd_terms = col("eligibility_criteria")
  )
  if (all(c("pd_important", "pd_nonimportant") %in% names(dfExclusion))) {
    df$flag_pd_important <- yn(col("pd_important"))
    df$flag_pd_nonimportant <- yn(col("pd_nonimportant"))
  }

  bPotential <- rep(FALSE, nrow(df))
  if (bPilot) {
    # NA throughout means the source is not delivered ("N/A"), not "no records".
    delivered <- function(x) if (all(is.na(x))) NA_character_ else yn(x)
    df$flag_edc_query <- delivered(col("edc_query"))
    df$flag_edc_pd <- delivered(col("edc_pd"))
    bPotential <- df$flag_edc_query %in% "Y" | df$flag_edc_pd %in% "Y"
  }

  df$status <- dplyr::case_when(
    bIneligible ~ ELIG_INELIGIBLE,
    bPotential ~ ELIG_POTENTIAL,
    TRUE ~ ELIG_NO_RISK
  )
  df$investigator <- elig_Investigator(df$invid, dfGroups)

  df[c(
    "studyid", "subjid", "country", "invid", "investigator", "status",
    intersect(names(ELIG_SOURCES), names(df)),
    "criteria", "criteria_type", "pd_dates", "pd_terms"
  )]
}

#' Is a flag source delivered?
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param strFlag `character` Flag column, e.g. `"flag_edc_pd"`.
#'
#' @return `logical`.
#'
#' @keywords internal
#' @export
elig_HasSource <- function(dfElig, strFlag) {
  strFlag %in% names(dfElig) && !all(is.na(dfElig[[strFlag]]))
}

#' Flag sources shown by the report
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return Named `character`: flag column = display name, in display order.
#'   The PD split replaces the single PD source when delivered, unless a PD is
#'   neither important nor non-important; EDC Query and EDC PD stay listed
#'   when not delivered, so the listing can show "N/A".
#'
#' @keywords internal
#' @export
elig_Sources <- function(dfElig) {
  vFlags <- intersect(names(ELIG_SOURCES), names(dfElig))
  bUnclassified <- dfElig[["flag_pd"]] %in% "Y" &
    dfElig[["flag_pd_important"]] %in% "N" & dfElig[["flag_pd_nonimportant"]] %in% "N"
  if (all(c("flag_pd_important", "flag_pd_nonimportant") %in% vFlags) && !any(bUnclassified)) {
    vFlags <- setdiff(vFlags, "flag_pd")
  }
  ELIG_SOURCES[vFlags]
}

elig_Investigator <- function(vInvid, dfGroups) {
  if (is.null(dfGroups) || !all(c("GroupID", "GroupLevel", "Param", "Value") %in% names(dfGroups))) {
    return(rep(NA_character_, length(vInvid)))
  }
  site <- dfGroups[dfGroups$GroupLevel == "Site" & dfGroups$Param %in% c("InvestigatorFirstName", "InvestigatorLastName"), ]
  if (nrow(site) == 0) return(rep(NA_character_, length(vInvid)))
  names <- site %>%
    dplyr::mutate(Value = dplyr::na_if(trimws(as.character(.data$Value)), "")) %>%
    dplyr::filter(!is.na(.data$Value)) %>%
    dplyr::arrange(.data$GroupID, match(.data$Param, c("InvestigatorFirstName", "InvestigatorLastName"))) %>%
    dplyr::summarise(name = paste(.data$Value, collapse = " "), .by = "GroupID")
  names$name[match(vInvid, names$GroupID)]
}

#' Inclusion or Exclusion criterion type
#'
#' The type comes only from the delivered category, never from the code text:
#' code formats differ between studies.
#'
#' @param vCategory `character` I/E categories from `iecat_concat`, such as
#'   `"IN"`, `"EX"`.
#'
#' @return `character` `"Inclusion"`, `"Exclusion"` or `"Not classified"`.
#'
#' @keywords internal
#' @export
elig_CriterionType <- function(vCategory) {
  dplyr::case_when(
    grepl("^\\s*IN", vCategory, ignore.case = TRUE) ~ "Inclusion",
    grepl("^\\s*EX", vCategory, ignore.case = TRUE) ~ "Exclusion",
    .default = "Not classified"
  )
}

#' Criterion cases
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `tibble` with one row per participant and EDC I/E criterion code:
#'   `subjid`, `country`, `invid`, `status`, `criterion` and `type`. A
#'   participant whose `criteria_type` does not pair one to one with the codes
#'   is Not classified.
#'
#' @keywords internal
#' @export
elig_CriteriaLong <- function(dfElig) {
  df <- dfElig[!is.na(dfElig$criteria) & nzchar(dfElig$criteria), ]
  if (nrow(df) == 0) {
    return(tibble::tibble(
      subjid = character(), country = character(), invid = character(),
      status = character(), criterion = character(), type = character()
    ))
  }
  lCodes <- strsplit(df$criteria, ",", fixed = TRUE)
  lTypes <- Map(
    function(codes, types) if (length(types) == length(codes)) types else rep(NA_character_, length(codes)),
    lCodes, strsplit(df$criteria_type, ",", fixed = TRUE)
  )
  n <- lengths(lCodes)
  tibble::tibble(
    subjid = rep(df$subjid, n), country = rep(df$country, n), invid = rep(df$invid, n),
    status = rep(df$status, n), criterion = trimws(unlist(lCodes)),
    type = elig_CriterionType(unlist(lTypes))
  ) %>%
    dplyr::filter(nzchar(.data$criterion)) %>%
    dplyr::distinct(.data$subjid, .data$criterion, .keep_all = TRUE)
}

#' Eligibility status counts of a snapshot
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Participants per study and status, classified as the report does. A pilot
#' study saves it every snapshot as `Reporting_EligStatus`; the snapshots
#' together are the report's `dfStatusHistory`.
#'
#' @inheritParams elig_ClassifyParticipants
#' @param strMode `character` `"basic"` (default) or `"pilot"`, resolved by
#'   [elig_Mode()].
#'
#' @return `tibble` with `GroupLevel` (`"Study"`), `GroupID` (study ID),
#'   `Status` and `n`.
#'
#' @export
elig_StatusCounts <- function(dfExclusion, strMode = c("basic", "pilot")) {
  dfElig <- elig_ClassifyParticipants(dfExclusion, strMode = elig_Mode(dfExclusion, strMode))
  dfElig %>%
    dplyr::count(GroupID = .data$studyid, Status = .data$status, name = "n") %>%
    dplyr::mutate(GroupLevel = "Study", n = as.integer(.data$n)) %>%
    dplyr::arrange(.data$GroupID, match(.data$Status, names(elig_StatusColors()))) %>%
    dplyr::select("GroupLevel", "GroupID", "Status", "n")
}

#' Status over time rows
#'
#' One bar per snapshot of the study's status history.
#'
#' @param dfStatusHistory `data.frame` Rows of [elig_StatusCounts()] from every
#'   snapshot, with `SnapshotDate`, or `NULL`.
#'
#' @return `tibble` with `GroupID` (snapshot date), `Status` and `n`.
#'
#' @keywords internal
#' @export
elig_TrendRows <- function(dfStatusHistory) {
  empty <- tibble::tibble(GroupID = character(), Status = character(), n = integer())
  if (!is.data.frame(dfStatusHistory)) return(empty)
  dfStatusHistory %>%
    dplyr::filter(.data$GroupLevel == "Study", .data$n > 0) %>%
    dplyr::arrange(as.Date(.data$SnapshotDate), match(.data$Status, names(elig_StatusColors()))) %>%
    dplyr::transmute(
      GroupID = format(as.Date(.data$SnapshotDate), "%Y-%m-%d"),
      Status = as.character(.data$Status),
      n = as.integer(.data$n)
    )
}

#' Rate metric of the eligibility results
#'
#' The module passes qtl0001 only; older callers rename it (for example
#' `"study_eligibility"`), so otherwise the rate is the first metric.
#'
#' @param dfResults `data.frame` Reporting results.
#'
#' @return `character` MetricID.
#'
#' @keywords internal
#' @export
elig_RateMetricID <- function(dfResults) {
  ids <- unique(dfResults$MetricID)
  if (ELIG_RATE_METRIC_ID %in% ids) return(ELIG_RATE_METRIC_ID)
  ids[1]
}
