#' @rdname Report_RepeatMeasurements
#' @export
rep_VitalRows <- function(lClass) {
  dfVitals <- lClass$vitals
  dfValues <- lClass$measurements %>%
    dplyr::arrange(.data$subjid, .data$vital, .data$seq) %>%
    dplyr::group_by(.data$subjid, .data$vital) %>%
    dplyr::summarise(
      values = paste(.data$value_text, collapse = " "),
      in_repeat_window = paste(
        as.integer(.data$in_repeat_window),
        collapse = " "
      ),
      visits = paste(
        sprintf(
          "#%s \u00b7 %s \u00b7 %s",
          .data$seq,
          dplyr::coalesce(as.character(.data$visit), "\u2013"),
          dplyr::coalesce(as.character(.data$vs_dt), "\u2013")
        ),
        collapse = "|"
      ),
      n_unique = dplyr::n_distinct(.data$value_text),
      .groups = "drop"
    )
  df <- lClass$participants %>%
    dplyr::left_join(dfValues, by = c("subjid", "vital"))
  tibble::tibble(
    country = as.character(df$country),
    invid = as.character(df$invid),
    subjid = df$subjid,
    label = dfVitals$label[match(df$vital, dfVitals$vital)],
    metric = dplyr::coalesce(df$metric, ""),
    n_unique = dplyr::coalesce(df$n_unique, 0L),
    flag = as.character(df$flag),
    measured = as.integer(df$n_records),
    Numerator = df$Numerator,
    Denominator = df$Denominator,
    rate = ifelse(df$Denominator > 0, round(df$rate, 4), NA_real_),
    values = dplyr::coalesce(df$values, ""),
    in_repeat_window = dplyr::coalesce(df$in_repeat_window, ""),
    visits = dplyr::coalesce(df$visits, ""),
    vital = df$vital,
    has_repeat = ifelse(grepl("1", df$in_repeat_window), "Y", "N"),
    severity = rep_FlagSeverity(df$flag)
  ) %>%
    # One row per participant and measure, so each row sorts by its own flag
    # and windows rather than the participant's worst (rep_ParticipantOrder()).
    dplyr::arrange(
      -.data$severity,
      -.data$Numerator,
      .data$subjid,
      match(.data$vital, dfVitals$vital)
    ) %>%
    dplyr::select(-"severity")
}

#' @rdname Report_RepeatMeasurements
#' @export
rep_VitalsListing <- function(
  dfVitalRows,
  nWindowLength = NULL,
  bExport = TRUE
) {
  idx <- function(col) match(col, names(dfVitalRows)) - 1L
  vLabels <- c(
    country = "Country",
    invid = "Site",
    subjid = "Participant",
    label = "Measure",
    metric = "Metric",
    n_unique = "Distinct",
    flag = "Flag \u00b7 rate",
    measured = "Measured",
    Numerator = "Numerator",
    Denominator = "Denominator",
    rate = "Rate",
    values = if (is.null(nWindowLength)) {
      "Measurements in order"
    } else {
      paste0("Measurements in order (window ", nWindowLength, ")")
    },
    in_repeat_window = "In repeating window",
    visits = "Visits",
    vital = "vital",
    has_repeat = "has_repeat"
  )
  DT::datatable(
    dfVitalRows,
    elementId = "rm-vitals",
    rownames = FALSE,
    colnames = unname(vLabels[names(dfVitalRows)]),
    extensions = "Buttons",
    selection = "none",
    class = "compact hover rm-show-values",
    options = list(
      dom = if (isTRUE(bExport)) "Bfrtip" else "frtip",
      pageLength = 25,
      deferRender = TRUE,
      order = list(),
      buttons = rep_CsvButton(
        bExport,
        "repeat-measurements-vitals",
        ":visible, .rm-export"
      ),
      createdRow = DT::JS(
        "function (row) { row.title = 'Click to filter the report to this participant; click again to clear'; }"
      ),
      columnDefs = c(
        lapply(
          c("country", "invid", "subjid", "Numerator", "Denominator"),
          function(col) list(targets = idx(col), name = col)
        ),
        list(
          list(
            targets = idx("label"),
            name = "label",
            render = DT::JS(sprintf(
              "function (data, type, row) {
                if (type !== 'display') return data;
                var m = row[%d];
                return '<span title=\"' + String(m || 'Not a KRI').replace(/\"/g, '&quot;') + '\">' + data + (m ? '' : '<span class=\"rm-nk\"> *</span>') + '</span>';
              }",
              idx("metric")
            ))
          ),
          list(
            targets = idx("n_unique"),
            name = "n_unique",
            orderSequence = list("asc", "desc"),
            render = DT::JS(sprintf(
              "function (data, type, row) {
                var total = row[%d];
                if (type === 'sort' || type === 'type') return total ? data / total : 2;
                if (type !== 'display') return data + ' / ' + total;
                return '<span title=\"' + data + ' distinct of ' + total + ' non-missing values\">' + data + ' / ' + total + '</span>';
              }",
              idx("measured")
            ))
          ),
          list(
            targets = idx("flag"),
            name = "flag",
            orderSequence = list("desc", "asc"),
            render = DT::JS(sprintf(
              "function (data, type, row) {
                var rate = row[%1$d];
                if (type === 'sort' || type === 'type') {
                  var sev = { 'Red': 3, 'Amber': 2, 'Green': 1, 'Not evaluable': 0 }[data] || 0;
                  return sev * 1000 + (rate === null ? -1 : rate * 100);
                }
                if (type !== 'display') return data;
                var c = %2$s[data] || '#FFFFFF';
                var pct = rate === null ? '\u2013' : (100 * rate).toFixed(0) + '%%';
                var tip = (row[%3$d] || 'Not a KRI') + ' \u00b7 ' + data + ' \u00b7 measured ' + row[%4$d] +
                  ' \u00b7 N ' + row[%5$d] + ' of D ' + row[%6$d] + ' windows repeating';
                return '<span class=\"rm-fr\" title=\"' + tip.replace(/\"/g, '&quot;') + '\"><span class=\"rm-dot\" style=\"background:' + c + '\"></span>' + (data === 'Not evaluable' ? data : data + ' \u00b7 ' + pct) + '</span>';
              }",
              idx("rate"),
              jsonlite::toJSON(as.list(rep_FlagColors()), auto_unbox = TRUE),
              idx("metric"),
              idx("measured"),
              idx("Numerator"),
              idx("Denominator")
            ))
          ),
          list(
            targets = idx("values"),
            orderable = FALSE,
            render = DT::JS(sprintf(
              "function (data, type, row) {
                if (type !== 'display' || !data) return data;
                var mask = String(row[%d]).split(' ');
                var visits = String(row[%d]).split('|');
                var esc = function (s) {
                  return String(s).replace(/&/g, '&amp;').replace(/\"/g, '&quot;').replace(/</g, '&lt;');
                };
                return '<span class=\"rm-vals\">' + String(data).split(' ').map(function (v, i) {
                  var rw = mask[i] === '1';
                  var tip = (visits[i] || '') + (rw ? ' \u00b7 in a repeating window' : '');
                  return '<b' + (rw ? ' class=\"rw\"' : '') + ' title=\"' + esc(tip) + '\">' + esc(v) + '</b>';
                }).join('') + '</span>';
              }",
              idx("in_repeat_window"),
              idx("visits")
            ))
          ),
          list(
            targets = idx(c(
              "metric",
              "measured",
              "Numerator",
              "Denominator",
              "rate",
              "in_repeat_window",
              "visits"
            )),
            visible = FALSE,
            className = "rm-export"
          )
        ),
        lapply(c("vital", "has_repeat"), function(col) {
          list(targets = idx(col), name = col, visible = FALSE)
        })
      )
    )
  )
}
