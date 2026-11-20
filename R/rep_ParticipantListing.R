#' @rdname Report_RepeatMeasurements
#' @export
rep_ParticipantTiles <- function(lClass) {
  dfVitals <- lClass$vitals
  df <- lClass$participants
  strRate <- ifelse(
    df$Denominator > 0,
    # Half up, as the browser's Math.round() does; round() goes to even.
    paste0(floor(100 * df$Numerator / df$Denominator + 0.5), "%"),
    "NE"
  )
  strND <- ifelse(
    df$Denominator > 0,
    paste0(df$Numerator, "/", df$Denominator),
    "NE"
  )
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
