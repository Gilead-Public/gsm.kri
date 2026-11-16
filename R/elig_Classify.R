# Eligibility report (gsm.roadmap#113): participant status, flag sources and
# criteria, derived once in R. Every chart, card and listing reads the frame of
# elig_ClassifyParticipants(); the report's JavaScript only filters it.

ELIG_INELIGIBLE <- "Ineligible"
ELIG_POTENTIAL <- "Potentially Ineligible"
ELIG_NO_RISK <- "No Eligibility Risk"

# Study-level history metric of the pilot studies (data contract level 3):
# (Ineligible + Potentially Ineligible) / enrolled. qtl0001 stays the rate.
ELIG_RISK_METRIC_ID <- "Analysis_elig0001"
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
#' Standard GISMO flag palette, keyed by status in chart stack order (first is
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
#' `"pilot"` when `Mapped_EXCLUSION` carries the optional `edc_query` flag
#' column (data contract level 1), otherwise `"basic"`.
#'
#' @param dfExclusion `data.frame` `Mapped_EXCLUSION`.
#'
#' @return `character` `"basic"` or `"pilot"`.
#'
#' @keywords internal
#' @export
elig_Mode <- function(dfExclusion) {
  if ("edc_query" %in% names(dfExclusion)) "pilot" else "basic"
}

#' Classify enrolled participants by eligibility status
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per enrolled participant of `Mapped_EXCLUSION` with exactly one
#' status:
#' - **Ineligible**: `Source != 'Neither'` (rules 2.4 and 2.5, applied upstream);
#' - **Potentially Ineligible** (pilot mode only): otherwise, the `edc_query`
#'   or `edc_pd` flag is `"Y"` (rules 2.6 and 2.7, applied in the study repo);
#' - **No Eligibility Risk**: otherwise.
#'
#' The flag sources never read `Source` values: the EDC eCRF flag is
#' `ie_violation`, the PD flag is `pd_violation`, or the presence of PD terms
#' (`eligibility_criteria`) when a study's EXCLUSION has no `pd_violation`.
#'
#' @param dfExclusion `data.frame` `Mapped_EXCLUSION`, optionally with the
#'   level 1 columns `pd_important`, `pd_nonimportant`, `edc_query` and
#'   `edc_pd` (`"Y"`/`"N"`; `edc_pd` is `NA` when not delivered).
#' @param dfGroups `data.frame` Reporting groups. Site-level
#'   `InvestigatorFirstName` / `InvestigatorLastName` give the investigator.
#'   Default: `NULL`.
#'
#' @return `tibble` with `studyid`, `subjid`, `country`, `invid`,
#'   `investigator`, `status`, the `flag_*` columns of the delivered sources
#'   (`"Y"`/`"N"`/`NA`), `criteria`, `pd_dates` and `pd_terms`.
#'
#' @keywords internal
#' @export
elig_ClassifyParticipants <- function(dfExclusion, dfGroups = NULL) {
  bPilot <- elig_Mode(dfExclusion) == "pilot"
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
    pd_dates = col("dvdtm"),
    pd_terms = col("eligibility_criteria")
  )
  if (all(c("pd_important", "pd_nonimportant") %in% names(dfExclusion))) {
    df$flag_pd_important <- yn(col("pd_important"))
    df$flag_pd_nonimportant <- yn(col("pd_nonimportant"))
  }

  bPotential <- rep(FALSE, nrow(df))
  if (bPilot) {
    df$flag_edc_query <- yn(col("edc_query"))
    edc_pd <- col("edc_pd")
    # NA throughout means the source is not delivered ("N/A"), not "no records".
    df$flag_edc_pd <- if (all(is.na(edc_pd))) NA_character_ else yn(edc_pd)
    bPotential <- df$flag_edc_query == "Y" | df$flag_edc_pd %in% "Y"
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
    "criteria", "pd_dates", "pd_terms"
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
#'   neither important nor non-important; EDC PD stays listed when not
#'   delivered, so the listing can show "N/A".
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
#' @param vCode `character` I/E test codes such as `"I001"`, `"excl7"`.
#'
#' @return `character` `"Inclusion"`, `"Exclusion"` or `"Other"`.
#'
#' @keywords internal
#' @export
elig_CriterionType <- function(vCode) {
  dplyr::case_when(
    grepl("^\\s*(I|INC)", vCode, ignore.case = TRUE) ~ "Inclusion",
    grepl("^\\s*(E|EXC)", vCode, ignore.case = TRUE) ~ "Exclusion",
    TRUE ~ "Other"
  )
}

#' Criterion cases
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `tibble` with one row per participant and EDC I/E criterion code:
#'   `subjid`, `country`, `invid`, `status`, `criterion` and `type`.
#'
#' @keywords internal
#' @export
elig_CriteriaLong <- function(dfElig) {
  df <- dfElig[!is.na(dfElig$criteria) & nzchar(dfElig$criteria), c("subjid", "country", "invid", "status", "criteria")]
  if (nrow(df) == 0) {
    return(tibble::tibble(
      subjid = character(), country = character(), invid = character(),
      status = character(), criterion = character(), type = character()
    ))
  }
  df %>%
    tidyr::separate_longer_delim("criteria", delim = ",") %>%
    dplyr::mutate(criterion = trimws(.data$criteria)) %>%
    dplyr::filter(nzchar(.data$criterion)) %>%
    dplyr::distinct(.data$subjid, .data$country, .data$invid, .data$status, .data$criterion) %>%
    dplyr::mutate(type = elig_CriterionType(.data$criterion)) %>%
    tibble::as_tibble()
}

#' Status over time rows
#'
#' One bar per snapshot that has both the rate metric (qtl0001) and the level 3
#' risk metric: Ineligible = qtl0001 numerator; Potentially Ineligible = risk
#' numerator - qtl0001 numerator; No Eligibility Risk = denominator - risk
#' numerator.
#'
#' @param dfResults `data.frame` Reporting results.
#'
#' @return `tibble` with `GroupID` (snapshot date), `Status` and `n`.
#'
#' @keywords internal
#' @export
elig_TrendRows <- function(dfResults) {
  empty <- tibble::tibble(GroupID = character(), Status = character(), n = integer())
  if (is.null(dfResults) || !ELIG_RISK_METRIC_ID %in% dfResults$MetricID) return(empty)
  pick <- function(id, cols) dfResults[dfResults$MetricID == id, cols]
  wide <- dplyr::inner_join(
    pick(elig_RateMetricID(dfResults), c("SnapshotDate", "Numerator", "Denominator")),
    pick(ELIG_RISK_METRIC_ID, c("SnapshotDate", "Numerator")),
    by = "SnapshotDate", suffix = c("_inel", "_risk")
  ) %>%
    dplyr::filter(.data$Denominator > 0) %>%
    dplyr::arrange(.data$SnapshotDate)
  if (nrow(wide) == 0) return(empty)
  out <- tibble::tibble(
    GroupID = rep(format(as.Date(wide$SnapshotDate), "%Y-%m-%d"), each = 3),
    Status = rep(names(elig_StatusColors()), times = nrow(wide)),
    n = as.integer(c(rbind(
      wide$Numerator_inel,
      wide$Numerator_risk - wide$Numerator_inel,
      wide$Denominator - wide$Numerator_risk
    )))
  )
  out[out$n > 0, ]
}

#' Rate metric of the eligibility results
#'
#' The module passes qtl0001 only; older callers rename it (for example
#' `"study_eligibility"`), so the rate is whichever metric is not the risk one.
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
  setdiff(ids, ELIG_RISK_METRIC_ID)[1]
}
