#' Participant Listing data for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One tile per participant and KRI vital, with the three cell labels the
#' report switches between, and one detail row per measurement for the
#' expanded columns.
#'
#' @param lClass `list` Output of [rm_Classify()].
#'
#' @return A `list` with `tiles` (`subjid`, `invid`, `country`, `vital`,
#'   `column`, `flag`, `severity`, `Numerator`, `Denominator`, `rate`, `n`,
#'   `label_rate`, `label_nd`, `label_both`), sorted by the participant's
#'   worst flag, then participant; and `detail` (`subjid`, `column`, `seq`,
#'   `value`, `in_repeat_window` ("Yes"/"No"), `visit`).
#' @keywords internal
#' @export
rm_ParticipantTiles <- function(lClass) {
  dfVitals <- rm_Vitals()
  vSeverity <- c(Red = 3L, Amber = 2L, Green = 1L, `Not evaluable` = 0L)
  df <- lClass$participants[!is.na(lClass$participants$metric), ]
  strRate <- ifelse(
    df$Denominator > 0,
    paste0(round(100 * df$Numerator / df$Denominator), "%"),
    "NE"
  )
  strND <- ifelse(df$Denominator > 0, paste0(df$Numerator, "/", df$Denominator), "NE")
  dfTiles <- tibble::tibble(
    subjid = df$subjid,
    invid = as.character(df$invid),
    country = as.character(df$country),
    vital = df$vital,
    column = dfVitals$short[match(df$vital, dfVitals$vital)],
    flag = as.character(df$flag),
    severity = unname(vSeverity[as.character(df$flag)]),
    Numerator = df$Numerator,
    Denominator = df$Denominator,
    rate = df$rate,
    n = df$n_records,
    label_rate = strRate,
    label_nd = strND,
    label_both = ifelse(df$Denominator > 0, paste0(strND, "\n", strRate), "NE")
  )
  dfWorst <- dfTiles %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      worst = max(.data$severity),
      most = max(.data$Numerator),
      .groups = "drop"
    )
  dfTiles <- dfTiles %>%
    dplyr::left_join(dfWorst, by = "subjid") %>%
    dplyr::arrange(
      -.data$worst,
      -.data$most,
      .data$subjid,
      match(.data$vital, dfVitals$vital)
    ) %>%
    dplyr::select(-"worst", -"most")

  dfM <- lClass$measurements[lClass$measurements$vital %in% dfTiles$vital, ]
  dfDetail <- tibble::tibble(
    subjid = dfM$subjid,
    column = dfVitals$short[match(dfM$vital, dfVitals$vital)],
    seq = as.integer(dfM$seq),
    value = dfM$value,
    in_repeat_window = ifelse(dfM$in_repeat_window, "Yes", "No"),
    visit = if (is.null(dfM$visit)) NA_character_ else as.character(dfM$visit)
  )
  list(tiles = dfTiles, detail = dfDetail)
}

#' gsm.viz tiles spec for the Repeat Measurements Participant Listing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Fill is the participant's flag for the vital; clicking a vital header
#' expands it into one column per measurement, repeat-window values
#' highlighted.
#'
#' @param dfDetail `data.frame` `detail` from [rm_ParticipantTiles()].
#' @param strLabel `character` Initial cell label: `"both"`, `"rate"` or
#'   `"nd"`.
#'
#' @return A named `list` for [gsm.vizr::tiles()].
#' @keywords internal
#' @export
rm_ParticipantTilesSpec <- function(dfDetail, strLabel = c("both", "rate", "nd")) {
  strLabel <- match.arg(strLabel)
  vColors <- rm_FlagColors()
  list(
    mapping = list(x = "column", y = "subjid", fill = "flag", label = paste0("label_", strLabel)),
    scales = list(
      x = list(label = "Vital (click to show measurements)"),
      y = list(label = "Participant"),
      fill = list(
        colors = as.list(vColors[c("Red", "Amber", "Green", "Not evaluable")]),
        label = "Flag"
      )
    ),
    expand = list(
      data = dfDetail,
      mapping = list(x = "seq", fill = "in_repeat_window", label = "value"),
      scales = list(fill = list(
        colors = list(Yes = "#B5462F", No = "#E8E8E8"),
        label = "In repeat window"
      )),
      tooltip = list(format = "{subjid} \u00b7 {column} #{seq} ({visit}): {value}")
    ),
    tooltip = list(
      format = "{subjid} \u00b7 site {invid} \u00b7 {column}: {flag} \u00b7 {Numerator} of {Denominator} windows repeat"
    ),
    rows = list(pageSize = 50L),
    theme = list(cellWidth = 72L, rowHeaderWidth = 110L, maxHeight = "560px")
  )
}
