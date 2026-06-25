#' Premature-death category levels
#'
#' @description
#' The five categories, in precedence order: death within 30 days, death
#' 31-`nWindowDays` days, study discontinuation within the window, alive at the
#' window (follow-up >= window), and alive prior to the window (follow-up <
#' window). Shared by the bucket bar, the scatter, and the report so labels and
#' colors stay in lockstep.
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A named length-5 `character` vector keyed `death30`, `death3190`,
#'   `discont`, `alive_at`, `alive_prior` (precedence order). The names are a
#'   stable internal contract; the label strings are what render.
#' @export
pd_CategoryLevels <- function(nWindowDays) {
  c(
    death30 = "Death within 30 days",
    death3190 = paste0("Death within 31\u2013", nWindowDays, " days"),
    discont = paste0("Study discontinuation within ", nWindowDays, " days"),
    alive_at = paste0("Alive at ", nWindowDays, " days"),
    alive_prior = paste0("Alive, not yet ", nWindowDays, " days on study")
  )
}

#' Premature-death category colors
#'
#' @description
#' Named color vector keyed by [pd_CategoryLevels()]: red/amber (deaths),
#' dark-grey (discontinuation), dark green (alive at window), light green
#' (alive prior to window). Reuses [colorScheme()] so no new hues are introduced.
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-5 named `character` vector of hex colors.
#' @export
pd_CategoryColors <- function(nWindowDays) {
  cols <- c(
    colorScheme("red", "dark"),
    colorScheme("amber", "dark"),
    colorScheme("gray", "dark"),
    colorScheme("green", "dark"),
    colorScheme("green", "light")
  )
  names(cols) <- pd_CategoryLevels(nWindowDays)
  cols
}

#' Premature-death bucket stacking order
#'
#' @description
#' Bottom-to-top stacking order for the bucket bars: best outcome at the base
#' (alive at the window), worst at the top (death within 30 days). This is a
#' *display* reordering only and is deliberately distinct from
#' [pd_CategoryLevels()], which stays in precedence order so classification,
#' colors, and the cross-filter keep working unchanged.
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-5 `character` vector: a reordering of [pd_CategoryLevels()].
#' @export
pd_DisplayOrder <- function(nWindowDays) {
  lv <- pd_CategoryLevels(nWindowDays)
  # Unnamed: this is a positional stacking order (base -> top), not a keyed lookup.
  unname(lv[c("alive_at", "alive_prior", "discont", "death3190", "death30")])
}

#' Classify enrolled subjects into premature-death categories
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Single source of truth for the five premature-death categories. Every enrolled
#' subject in `dfSubjects` is assigned exactly one `Category` by precedence
#' (first match wins): death `<=30d` -> death `31-Wd` -> study discontinuation
#' within the window -> alive at the window (`follow_up >= nWindowDays`, which
#' includes a death after the window -- it survived the window) -> alive prior to
#' the window. `discont_dy` is `discontinuation_date - rgmn_dt`, mirroring how
#' `death_dy` is derived, so the whole report shares one day-zero (randomization).
#'
#' @param dfSubjects `data.frame` Enrolled subjects: `subjid` (+ `studyid` /
#'   `country` / `invid` when present). Needs `rgmn_dt`, or supply `dfRand`.
#' @param dfDeath `data.frame` Mapped death data with `subjid` and `death_dy`.
#' @param dfStudComp `data.frame` (optional) Study-completion data with `subjid`,
#'   `compyn`, `compreas`, and `strDiscontDateCol`. `NULL` (default) yields no
#'   discontinuation category.
#' @param dfRand `data.frame` (optional) Randomization data with `subjid` and
#'   `rgmn_dt`, used when `dfSubjects` lacks `rgmn_dt`.
#' @param nWindowDays `numeric` Window in days. Default 90.
#' @param dSnapshotDate `Date` Reporting snapshot (drives `follow_up`). Default `Sys.Date()`.
#' @param strDiscontDateCol `character` Column in `dfStudComp` used as the
#'   discontinuation date. Default `"mincreated_dts"` (a proxy; repoint to a true
#'   discontinuation/end-of-study date when one is mapped).
#' @param strDeathReason `character` `compreas` value meaning death (excluded from
#'   the discontinuation category). Default `"Death"`.
#'
#' @return A `tibble`: `subjid`, `studyid`, `country`, `invid`, `Category`
#'   (factor with the [pd_CategoryLevels()] levels), `death_dy`, `discont_dy`,
#'   `follow_up`, `x_anchor`.
#' @export
pd_Classify <- function(
  dfSubjects,
  dfDeath,
  dfStudComp = NULL,
  dfRand = NULL,
  nWindowDays = 90,
  dSnapshotDate = Sys.Date(),
  strDiscontDateCol = "mincreated_dts",
  strDeathReason = "Death"
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfSubjects),
    message = "dfSubjects is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  lv <- pd_CategoryLevels(nWindowDays)

  subj <- dfSubjects %>% dplyr::distinct(.data$subjid, .keep_all = TRUE)
  if (!"rgmn_dt" %in% names(subj) && !is.null(dfRand)) {
    subj <- subj %>%
      dplyr::left_join(
        dfRand %>% dplyr::select("subjid", "rgmn_dt") %>% dplyr::distinct(),
        by = "subjid"
      )
  }
  gsm.core::stop_if(
    cnd = !"rgmn_dt" %in% names(subj),
    message = "pd_Classify needs rgmn_dt on dfSubjects or a dfRand carrying rgmn_dt"
  )

  death_dy <- dfDeath$death_dy[match(subj$subjid, dfDeath$subjid)]

  discont_dy <- rep(NA_real_, nrow(subj))
  if (!is.null(dfStudComp) && strDiscontDateCol %in% names(dfStudComp)) {
    dc <- dfStudComp %>%
      dplyr::filter(
        toupper(.data$compyn) %in% c("N", "NO", "FALSE"),
        is.na(.data$compreas) | .data$compreas != strDeathReason
      ) %>%
      dplyr::transmute(
        subjid = .data$subjid,
        discont_dt = as.Date(.data[[strDiscontDateCol]])
      ) %>%
      dplyr::group_by(.data$subjid) %>%
      dplyr::slice(1) %>%
      dplyr::ungroup()
    discont_dt <- dc$discont_dt[match(subj$subjid, dc$subjid)]
    discont_dy <- as.numeric(discont_dt - subj$rgmn_dt)
  }

  follow_up <- as.numeric(as.Date(dSnapshotDate) - subj$rgmn_dt)

  is_premature <- !is.na(death_dy) & death_dy <= nWindowDays
  is_discont <- !is.na(discont_dy) & discont_dy <= nWindowDays

  category <- dplyr::case_when(
    is_premature & death_dy <= 30 ~ lv[["death30"]],
    is_premature ~ lv[["death3190"]],
    is_discont ~ lv[["discont"]],
    follow_up >= nWindowDays ~ lv[["alive_at"]],
    TRUE ~ lv[["alive_prior"]]
  )

  x_anchor <- dplyr::case_when(
    is_premature ~ death_dy,
    is_discont ~ discont_dy,
    category == lv[["alive_at"]] ~ as.numeric(nWindowDays),
    TRUE ~ follow_up
  )

  pick <- function(col) if (col %in% names(subj)) subj[[col]] else NA_character_

  tibble::tibble(
    subjid = subj$subjid,
    studyid = pick("studyid"),
    # Label missing country "Unknown" here -- the one upstream place -- so the
    # country bucket bar (country is the GroupID), the scatter customdata, the
    # enrolled-count lookup, and the JS click->site map all share one keyspace.
    country = pd_CountryLabel(pick("country")),
    invid = pick("invid"),
    Category = factor(category, levels = lv),
    death_dy = death_dy,
    discont_dy = discont_dy,
    follow_up = follow_up,
    x_anchor = x_anchor
  )
}
