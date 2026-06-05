#' Premature-death cohort
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The single definition of "premature death within the window": the rows of
#' `dfDeath` whose `death_dy` is non-missing and at or before `nWindowDays`.
#' When `dfSubjects` is supplied, each death is left-joined to its subject's
#' identity columns (`studyid` / `country` / `invid`, whichever are present) so
#' callers can group or filter by site and country. Centralizing the predicate
#' keeps the scatter, reason counts, and the report agreeing on what counts as
#' premature.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid` and `death_dy`.
#' @param dfSubjects `data.frame` (optional) Mapped subject data keyed on
#'   `subjid`. When supplied, its `studyid` / `country` / `invid` columns (those
#'   present) are joined onto each death. Default: `NULL` (no join).
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#'
#' @return A `data.frame` of the premature `dfDeath` rows, with subject identity
#'   columns appended when `dfSubjects` is supplied.
#' @export
pd_PrematureCohort <- function(dfDeath, dfSubjects = NULL, nWindowDays = 90) {
  dfCohort <- dfDeath %>%
    dplyr::filter(!is.na(.data$death_dy) & .data$death_dy <= nWindowDays)

  if (!is.null(dfSubjects)) {
    # Attach subject identity columns, but skip any already on dfDeath: a death
    # frame that carries its own studyid would otherwise collide into
    # studyid.x / studyid.y and lose the plain column callers group on.
    join_cols <- setdiff(
      intersect(c("studyid", "country", "invid"), names(dfSubjects)),
      names(dfCohort)
    )
    dfCohort <- dfCohort %>%
      dplyr::left_join(
        dfSubjects %>%
          dplyr::select("subjid", dplyr::all_of(join_cols)) %>%
          dplyr::distinct(),
        by = "subjid"
      )
  }

  dfCohort
}
