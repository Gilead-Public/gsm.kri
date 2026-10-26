#' Participant Listing data for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One tile per participant and KRI vital, with the three tile labels the
#' report switches between. [Widget_RepeatMeasurementsTiles()] draws them.
#'
#' @param lClass `list` Output of [rm_Classify()].
#'
#' @return A `tibble` with `subjid`, `invid`, `country`, `vital`, `column`,
#'   `flag`, `severity`, `Numerator`, `Denominator`, `rate`, `n`,
#'   `label_rate`, `label_nd` and `label_both`, sorted by the participant's
#'   worst flag, then most repeating windows, then participant.
#' @keywords internal
#' @export
rm_ParticipantTiles <- function(lClass) {
  dfVitals <- rm_Vitals()
  vSeverity <- c(Red = 3L, Amber = 2L, Green = 1L, `Not evaluable` = 0L)
  df <- lClass$participants[lClass$participants$flag != "No KRI", ]
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
}
