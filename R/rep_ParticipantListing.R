#' Participant Listing data for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One tile per participant and measure, with the three tile labels the
#' report switches between. [Widget_RepeatMeasurementsTiles()] draws them.
#'
#' @param lClass `list` Output of [rep_Classify()].
#'
#' @return A `tibble` with `subjid`, `invid`, `country`, `vital`, `column`,
#'   `flag`, `severity`, `Numerator`, `Denominator`, `rate`, `n`,
#'   `label_rate`, `label_nd` and `label_both`, sorted by the participant's
#'   worst flag, then most repeating windows, then participant.
#' @keywords internal
#' @export
rep_ParticipantTiles <- function(lClass) {
  dfVitals <- lClass$vitals
  df <- lClass$participants
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
    severity = rep_FlagSeverity(df$flag),
    Numerator = df$Numerator,
    Denominator = df$Denominator,
    rate = df$rate,
    n = df$n_records,
    label_rate = strRate,
    label_nd = strND,
    label_both = ifelse(df$Denominator > 0, paste0(strND, "\n", strRate), "NE")
  )
  dfTiles %>%
    dplyr::arrange(
      match(.data$subjid, rep_ParticipantOrder(lClass)),
      match(.data$vital, dfVitals$vital)
    )
}
